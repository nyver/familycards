// Command wallet runs the Family Card Wallet sync server.
package main

import (
	"context"
	"crypto/tls"
	"database/sql"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"golang.org/x/crypto/acme/autocert"

	"familycards/server/internal/admin"
	"familycards/server/internal/auth"
	"familycards/server/internal/blobs"
	"familycards/server/internal/config"
	"familycards/server/internal/httpapi"
	"familycards/server/internal/logging"
	"familycards/server/internal/membership"
	"familycards/server/internal/migrations"
	"familycards/server/internal/ratelimit"
	"familycards/server/internal/storage"
	"familycards/server/internal/sync"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		// Config errors happen before logging is configured; print to
		// stderr directly. The error message never includes secret values.
		os.Stderr.WriteString(err.Error() + "\n")
		os.Exit(1)
	}

	logger := logging.New(cfg.LogLevel)
	slog.SetDefault(logger)

	if cfg.AllowInsecure {
		slog.Warn("WALLET_ALLOW_INSECURE is set: HTTPS enforcement is disabled, do not use in production")
	}

	if err := os.MkdirAll(filepath.Dir(cfg.DBPath), 0o755); err != nil {
		slog.Error("failed to create database directory", "error", err)
		os.Exit(1)
	}
	if err := os.MkdirAll(cfg.BlobDir, 0o755); err != nil {
		slog.Error("failed to create blob directory", "error", err)
		os.Exit(1)
	}

	db, err := storage.Open(cfg.DBPath)
	if err != nil {
		slog.Error("failed to open database", "error", err)
		os.Exit(1)
	}
	defer db.Close()

	ctx := context.Background()
	if err := migrations.Apply(ctx, db.Write); err != nil {
		slog.Error("failed to apply migrations", "error", err)
		os.Exit(1)
	}

	tokens := auth.NewTokenManager(cfg.JWTSecret)
	authMiddleware := auth.NewMiddleware(tokens, db.Read)
	authHandlers := auth.NewHandlers(db, tokens, cfg.BootstrapToken, cfg.JWTSecret)
	membershipHandlers := membership.NewHandlers(db, tokens)
	syncHandlers := sync.NewHandlers(db)
	blobStore := blobs.NewStore(cfg.BlobDir)
	blobHandlers := blobs.NewHandlers(db, blobStore)
	adminHandlers := admin.NewHandlers(db.Write, filepath.Dir(cfg.DBPath), cfg.BlobDir, cfg.AdminToken)

	authLimiter := ratelimit.New(10, time.Hour)
	generalLimiter := ratelimit.New(120, time.Hour)
	go sweepLimiters(ctx, authLimiter, generalLimiter)
	go hourlySummary(ctx, db.Read)
	go cleanupTombstones(ctx, db.Write, cfg.TombstoneDays)
	go runBlobGC(ctx, db, blobStore)

	// tlsTerminatedLocally and trustProxy are derived from cfg.TLSMode
	// here, in the one place that matters: whether the process itself
	// terminates TLS. See the comment on RouterConfig below for why they
	// must move together.
	tlsTerminatedLocally := cfg.TLSMode != config.TLSModeOff
	trustProxy := !cfg.AllowInsecure && !tlsTerminatedLocally

	var tlsConfig *tls.Config
	var acmeManager *autocert.Manager
	if tlsTerminatedLocally {
		if cfg.TLSMode == config.TLSModeACME || cfg.TLSMode == config.TLSModeSelfSigned {
			// DirCache/selfsigned.LoadOrIssue also create this directory,
			// but doing it explicitly upfront with the intended mode
			// avoids relying on their defaults and fails fast if the
			// parent path is not writable.
			if err := os.MkdirAll(cfg.TLSCacheDir, 0o700); err != nil {
				slog.Error("failed to create TLS cache directory", "error", err)
				os.Exit(1)
			}
		}
		var err error
		tlsConfig, acmeManager, err = buildTLSConfig(cfg)
		if err != nil {
			slog.Error("failed to configure TLS", "error", err)
			os.Exit(1)
		}
	}

	handler := httpapi.Router(httpapi.RouterConfig{
		ReadDB: db.Read,
		Auth: httpapi.AuthEndpoints{
			Bootstrap:        authHandlers.Bootstrap,
			Prelogin:         authHandlers.Prelogin,
			Login:            authHandlers.Login,
			Refresh:          authHandlers.Refresh,
			Logout:           authHandlers.Logout,
			ChangePassword:   authHandlers.ChangePassword,
			Me:               authHandlers.Me,
			RecoveryPrelogin: authHandlers.RecoveryPrelogin,
			RecoveryRedeem:   authHandlers.RecoveryRedeem,
		},
		Membership: httpapi.MembershipEndpoints{
			CreateInvite: membershipHandlers.CreateInvite,
			GetInvite:    membershipHandlers.GetInvite,
			RedeemInvite: membershipHandlers.RedeemInvite,
			DeleteInvite: membershipHandlers.DeleteInvite,
			ListMembers:  membershipHandlers.ListMembers,
			RemoveMember: membershipHandlers.RemoveMember,
		},
		Sync: httpapi.SyncEndpoints{
			GetChanges: syncHandlers.GetChanges,
			Push:       syncHandlers.Push,
		},
		Blobs: httpapi.BlobEndpoints{
			Upload: blobHandlers.Upload,
			Get:    blobHandlers.Get,
		},
		Admin: httpapi.AdminEndpoints{
			Backup: adminHandlers.Backup,
		},
		RequireAuth:   authMiddleware.RequireAuth,
		AllowInsecure: cfg.AllowInsecure,
		// tlsTerminatedLocally and trustProxy are derived from cfg.TLSMode
		// in this one place so they can never disagree: TrustProxy must be
		// false whenever we terminate TLS ourselves, since there is then
		// no real reverse proxy to have set X-Forwarded-For, and trusting
		// it would let any client forge its IP and bypass rate limiting.
		// In the "off" mode (behind an external proxy such as Caddy) the
		// forwarded headers remain trustworthy, exactly as before.
		TLSTerminatedLocally: tlsTerminatedLocally,
		TrustProxy:           trustProxy,
		AuthLimiter:          authLimiter,
		GeneralLimiter:       generalLimiter,
	})

	srv := &http.Server{
		Addr:              cfg.Addr,
		Handler:           handler,
		ReadHeaderTimeout: 10 * time.Second,
		TLSConfig:         tlsConfig,
	}

	// Both listeners report their fatal errors on this shared channel so a
	// bind failure on either one triggers a coordinated shutdown of both,
	// rather than leaving an already-running listener stuck (the old code
	// called os.Exit(1) directly from the goroutine, which could not do
	// that with a second listener in the picture).
	errCh := make(chan error, 2)

	go func() {
		slog.Info("wallet server starting", "addr", cfg.Addr, "tls_mode", string(cfg.TLSMode))
		var err error
		if tlsTerminatedLocally {
			err = srv.ListenAndServeTLS("", "")
		} else {
			err = srv.ListenAndServe()
		}
		if err != nil && err != http.ErrServerClosed {
			errCh <- fmt.Errorf("listen on %s: %w", cfg.Addr, err)
			return
		}
		errCh <- nil
	}()

	var httpSrv *http.Server
	if cfg.HTTPAddr != "" {
		// This listener's handler never routes into the main API router:
		// every path except the ACME challenge gets nothing but a 308
		// redirect, so a request with a body (e.g. a login attempt) is
		// never read or acted on over the plaintext port.
		var redirectHandler http.Handler = newRedirectHandler(httpsPort(cfg.Addr))
		if cfg.TLSMode == config.TLSModeACME && acmeManager != nil {
			redirectHandler = acmeManager.HTTPHandler(redirectHandler)
		}
		httpSrv = &http.Server{
			Addr:              cfg.HTTPAddr,
			Handler:           redirectHandler,
			ReadHeaderTimeout: 10 * time.Second,
		}
		go func() {
			slog.Info("wallet http redirect listener starting", "addr", cfg.HTTPAddr)
			if err := httpSrv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
				errCh <- fmt.Errorf("listen on %s: %w", cfg.HTTPAddr, err)
				return
			}
			errCh <- nil
		}()
	}

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)

	exitCode := 0
	select {
	case <-stop:
		slog.Info("wallet server shutting down")
	case err := <-errCh:
		if err != nil {
			slog.Error("server failed", "error", err)
			exitCode = 1
		}
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		slog.Error("graceful shutdown failed", "error", err, "addr", cfg.Addr)
	}
	if httpSrv != nil {
		if err := httpSrv.Shutdown(shutdownCtx); err != nil {
			slog.Error("graceful shutdown failed", "error", err, "addr", cfg.HTTPAddr)
		}
	}

	if exitCode != 0 {
		os.Exit(exitCode)
	}
}

func sweepLimiters(ctx context.Context, limiters ...*ratelimit.Limiter) {
	ticker := time.NewTicker(10 * time.Minute)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			for _, l := range limiters {
				l.Sweep()
			}
		}
	}
}

func cleanupTombstones(ctx context.Context, writeDB *sql.DB, tombstoneDays int) {
	ticker := time.NewTicker(24 * time.Hour)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			cutoff := time.Now().AddDate(0, 0, -tombstoneDays).UnixMilli()
			n, err := sync.DeleteTombstonesOlderThan(ctx, writeDB, cutoff)
			if err != nil {
				slog.Error("failed to clean up old tombstones", "error", err)
				continue
			}
			if n > 0 {
				slog.Info("cleaned up old tombstones", "count", n)
			}
		}
	}
}

func runBlobGC(ctx context.Context, db *storage.DB, store *blobs.Store) {
	ticker := time.NewTicker(24 * time.Hour)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			unreferenced, orphaned, err := blobs.RunGC(ctx, db, store, time.Now().Unix())
			if err != nil {
				slog.Error("blob garbage collection failed", "error", err)
				continue
			}
			if unreferenced > 0 || orphaned > 0 {
				slog.Info("blob garbage collection completed", "unreferenced_removed", unreferenced, "orphaned_removed", orphaned)
			}
		}
	}
}

func hourlySummary(ctx context.Context, readDB *sql.DB) {
	ticker := time.NewTicker(time.Hour)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			itemCount, blobCount, dbSize, err := httpapi.Summary(ctx, readDB)
			if err != nil {
				slog.Error("failed to compute summary", "error", err)
				continue
			}
			slog.Info("hourly summary", "item_count", itemCount, "blob_count", blobCount, "db_size", dbSize)
		}
	}
}
