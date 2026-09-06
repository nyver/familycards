package main

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"net/url"
	"sync"

	"golang.org/x/crypto/acme/autocert"

	"familycards/server/internal/config"
	"familycards/server/internal/selfsigned"
)

// buildTLSConfig constructs the *tls.Config the main HTTPS listener should
// use for cfg.TLSMode, and logs the fingerprint of the certificate that
// ends up being served (directly for file/selfsigned, since the
// certificate is known upfront; lazily for acme, since certificates are
// obtained on demand per SNI name). It also returns the autocert.Manager
// for acme mode (nil otherwise), needed to serve the HTTP-01 challenge on
// the redirect listener.
func buildTLSConfig(cfg config.Config) (*tls.Config, *autocert.Manager, error) {
	switch cfg.TLSMode {
	case config.TLSModeFile:
		cert, err := tls.LoadX509KeyPair(cfg.TLSCertFile, cfg.TLSKeyFile)
		if err != nil {
			return nil, nil, fmt.Errorf("load TLS certificate/key: %w", err)
		}
		logFingerprintOnce(cert)
		return &tls.Config{
			MinVersion:   tls.VersionTLS12,
			Certificates: []tls.Certificate{cert},
		}, nil, nil

	case config.TLSModeSelfSigned:
		cert, err := selfsigned.LoadOrIssue(cfg.TLSCacheDir, cfg.TLSDomains)
		if err != nil {
			return nil, nil, fmt.Errorf("issue self-signed certificate: %w", err)
		}
		logFingerprintOnce(cert)
		return &tls.Config{
			MinVersion:   tls.VersionTLS12,
			Certificates: []tls.Certificate{cert},
		}, nil, nil

	case config.TLSModeACME:
		// HostPolicy is required: without it, autocert attempts to issue a
		// certificate for whatever SNI name a client presents, letting an
		// attacker who points arbitrary hostnames at this server's IP
		// exhaust Let's Encrypt's rate limit.
		manager := &autocert.Manager{
			Cache:      autocert.DirCache(cfg.TLSCacheDir),
			HostPolicy: autocert.HostWhitelist(cfg.TLSDomains...),
			Prompt:     autocert.AcceptTOS,
			Email:      cfg.TLSACMEEmail,
		}
		tlsConfig := manager.TLSConfig()
		tlsConfig.MinVersion = tls.VersionTLS12
		tlsConfig.GetCertificate = wrapWithFingerprintLogging(tlsConfig.GetCertificate)
		return tlsConfig, manager, nil

	default:
		return nil, nil, fmt.Errorf("unsupported TLS mode %q", cfg.TLSMode)
	}
}

// logFingerprintOnce logs the SHA-256 fingerprint of a known-upfront
// certificate (file or selfsigned mode) at startup.
func logFingerprintOnce(cert tls.Certificate) {
	leaf := cert.Leaf
	if leaf == nil && len(cert.Certificate) > 0 {
		if parsed, err := x509.ParseCertificate(cert.Certificate[0]); err == nil {
			leaf = parsed
		}
	}
	if leaf == nil {
		slog.Warn("tls: could not parse certificate to log its fingerprint")
		return
	}
	slog.Info("tls certificate fingerprint (verify this against the client before pinning)",
		"fingerprint", selfsigned.Fingerprint(leaf))
}

// wrapWithFingerprintLogging wraps an autocert GetCertificate function so
// that the fingerprint of each distinct certificate it hands out is logged
// the first time it is served, without spamming the log on every
// subsequent handshake for an already-logged certificate.
func wrapWithFingerprintLogging(get func(*tls.ClientHelloInfo) (*tls.Certificate, error)) func(*tls.ClientHelloInfo) (*tls.Certificate, error) {
	var (
		mu     sync.Mutex
		logged = make(map[string]bool)
	)
	return func(hello *tls.ClientHelloInfo) (*tls.Certificate, error) {
		cert, err := get(hello)
		if err != nil || cert == nil || len(cert.Certificate) == 0 {
			return cert, err
		}
		leaf := cert.Leaf
		if leaf == nil {
			parsed, perr := x509.ParseCertificate(cert.Certificate[0])
			if perr != nil {
				return cert, err
			}
			leaf = parsed
		}
		fp := selfsigned.Fingerprint(leaf)
		mu.Lock()
		alreadyLogged := logged[fp]
		logged[fp] = true
		mu.Unlock()
		if !alreadyLogged {
			slog.Info("tls certificate fingerprint (verify this against the client before pinning)",
				"fingerprint", fp, "server_name", hello.ServerName)
		}
		return cert, err
	}
}

// httpsPort extracts the port the HTTPS listener binds to from
// WALLET_ADDR, so the HTTP redirect handler can encode it in the Location
// header when it is not the standard 443.
func httpsPort(addr string) string {
	_, port, err := net.SplitHostPort(addr)
	if err != nil {
		return ""
	}
	return port
}

// newRedirectHandler returns a handler that answers every request with a
// 308 redirect to the same host and path on the https scheme, encoding
// httpsPort in the Location header when it is not the standard 443. 308
// (not 301/302) preserves the request method, so a POST is retried as a
// POST rather than being downgraded to GET.
func newRedirectHandler(httpsPort string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		host := r.Host
		if h, _, err := net.SplitHostPort(host); err == nil {
			host = h
		}
		if httpsPort != "" && httpsPort != "443" {
			host = net.JoinHostPort(host, httpsPort)
		}
		target := url.URL{
			Scheme:   "https",
			Host:     host,
			Path:     r.URL.Path,
			RawQuery: r.URL.RawQuery,
		}
		http.Redirect(w, r, target.String(), http.StatusPermanentRedirect)
	})
}
