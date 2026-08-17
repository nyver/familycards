package httpapi

import (
	"database/sql"
	"net/http"
	"strings"

	"familycards/server/internal/ratelimit"
)

// AuthEndpoints is the subset of auth.Handlers exposed as plain
// http.HandlerFunc, kept as an interface here so httpapi does not import
// the auth package (avoiding a dependency cycle, since auth imports
// httpapi for the shared response helpers).
type AuthEndpoints struct {
	Bootstrap        http.HandlerFunc
	Prelogin         http.HandlerFunc
	Login            http.HandlerFunc
	Refresh          http.HandlerFunc
	Logout           http.HandlerFunc
	ChangePassword   http.HandlerFunc
	Me               http.HandlerFunc
	RecoveryPrelogin http.HandlerFunc
	RecoveryRedeem   http.HandlerFunc
}

// MembershipEndpoints is the invites/members endpoint set. GetInvite and
// RedeemInvite are unauthenticated (the caller has no account yet);
// everything else requires bearer auth.
type MembershipEndpoints struct {
	CreateInvite http.HandlerFunc
	GetInvite    http.HandlerFunc
	RedeemInvite http.HandlerFunc
	DeleteInvite http.HandlerFunc
	ListMembers  http.HandlerFunc
	RemoveMember http.HandlerFunc
}

// SyncEndpoints is the delta sync endpoint set.
type SyncEndpoints struct {
	GetChanges http.HandlerFunc
	Push       http.HandlerFunc
}

// BlobEndpoints is the blob storage endpoint set.
type BlobEndpoints struct {
	Upload http.HandlerFunc
	Get    http.HandlerFunc
}

// AdminEndpoints is the operator-only endpoint set, gated by X-Admin-Token
// rather than bearer auth.
type AdminEndpoints struct {
	Backup http.HandlerFunc
}

// RouterConfig bundles everything Router needs to assemble the full route
// table and middleware chain.
type RouterConfig struct {
	ReadDB         *sql.DB
	Auth           AuthEndpoints
	Membership     MembershipEndpoints
	Sync           SyncEndpoints
	Blobs          BlobEndpoints
	Admin          AdminEndpoints
	RequireAuth    func(http.Handler) http.Handler
	AllowInsecure  bool
	TrustProxy     bool
	AuthLimiter    *ratelimit.Limiter
	GeneralLimiter *ratelimit.Limiter
}

// Router builds the full *http.ServeMux with routing, middleware, and rate
// limiting wired up.
func Router(cfg RouterConfig) http.Handler {
	mux := http.NewServeMux()

	protect := func(h http.HandlerFunc) http.Handler {
		return cfg.RequireAuth(h)
	}

	mux.HandleFunc("GET /v1/health", HealthHandler(cfg.ReadDB))

	// Pre-authentication flows: no bearer token available yet.
	mux.HandleFunc("POST /v1/auth/bootstrap", cfg.Auth.Bootstrap)
	mux.HandleFunc("POST /v1/auth/prelogin", cfg.Auth.Prelogin)
	mux.HandleFunc("POST /v1/auth/login", cfg.Auth.Login)
	mux.HandleFunc("POST /v1/auth/refresh", cfg.Auth.Refresh)
	mux.HandleFunc("POST /v1/auth/recovery/prelogin", cfg.Auth.RecoveryPrelogin)
	mux.HandleFunc("POST /v1/auth/recovery/redeem", cfg.Auth.RecoveryRedeem)

	// Everything else under /v1/auth requires bearer auth.
	mux.Handle("POST /v1/auth/logout", protect(cfg.Auth.Logout))
	mux.Handle("POST /v1/auth/password", protect(cfg.Auth.ChangePassword))
	mux.Handle("GET /v1/me", protect(cfg.Auth.Me))

	if cfg.Membership.CreateInvite != nil {
		mux.Handle("POST /v1/invites", protect(cfg.Membership.CreateInvite))
		mux.HandleFunc("GET /v1/invites/{code_hash}", cfg.Membership.GetInvite)
		mux.HandleFunc("POST /v1/invites/{code_hash}/redeem", cfg.Membership.RedeemInvite)
		mux.Handle("DELETE /v1/invites/{code_hash}", protect(cfg.Membership.DeleteInvite))
		mux.Handle("GET /v1/members", protect(cfg.Membership.ListMembers))
		mux.Handle("DELETE /v1/members/{user_id}", protect(cfg.Membership.RemoveMember))
	}

	if cfg.Sync.GetChanges != nil {
		mux.Handle("GET /v1/sync/changes", protect(cfg.Sync.GetChanges))
		mux.Handle("POST /v1/sync/push", protect(cfg.Sync.Push))
	}

	if cfg.Blobs.Upload != nil {
		mux.Handle("POST /v1/blobs", protect(cfg.Blobs.Upload))
		mux.Handle("GET /v1/blobs/{blob_id}", protect(cfg.Blobs.Get))
	}

	// Admin endpoints use their own token, not bearer auth.
	if cfg.Admin.Backup != nil {
		mux.HandleFunc("POST /v1/admin/backup", cfg.Admin.Backup)
	}

	var handler http.Handler = mux
	handler = LimitBody(handler)
	handler = dualRateLimit(cfg.AuthLimiter, cfg.GeneralLimiter)(handler)
	handler = EnforceHTTPS(cfg.AllowInsecure)(handler)
	handler = ResolveClientIP(cfg.TrustProxy)(handler)
	handler = RequestLogger(handler)
	handler = Recover(handler)
	return handler
}

// dualRateLimit applies authLimiter to /v1/auth/* and generalLimiter to
// everything else, as required by the ops spec (10/min vs 120/min).
func dualRateLimit(authLimiter, generalLimiter *ratelimit.Limiter) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			limiter := generalLimiter
			if strings.HasPrefix(r.URL.Path, "/v1/auth/") {
				limiter = authLimiter
			}
			ratelimit.Middleware(limiter, ClientIP)(next).ServeHTTP(w, r)
		})
	}
}
