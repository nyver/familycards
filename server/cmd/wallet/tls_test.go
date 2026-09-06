package main

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"golang.org/x/crypto/acme/autocert"
)

func TestNewRedirectHandler_308ToHTTPSSamePath(t *testing.T) {
	handler := newRedirectHandler("8443")

	req := httptest.NewRequest(http.MethodGet, "http://example.com/v1/health?x=1", nil)
	req.Host = "example.com"
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusPermanentRedirect {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusPermanentRedirect)
	}
	want := "https://example.com:8443/v1/health?x=1"
	if got := rec.Header().Get("Location"); got != want {
		t.Errorf("Location = %q, want %q", got, want)
	}
}

func TestNewRedirectHandler_StandardPortOmittedFromLocation(t *testing.T) {
	handler := newRedirectHandler("443")

	req := httptest.NewRequest(http.MethodGet, "http://example.com/v1/health", nil)
	req.Host = "example.com"
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	want := "https://example.com/v1/health"
	if got := rec.Header().Get("Location"); got != want {
		t.Errorf("Location = %q, want %q", got, want)
	}
}

func TestNewRedirectHandler_POSTGetsSameRedirectStatus(t *testing.T) {
	// 308 (not 301/302) is what keeps a client from downgrading a POST to
	// GET when it follows the redirect - this test only checks the status
	// code, since whether the method survives is entirely the requesting
	// client's responsibility once it sees 308.
	handler := newRedirectHandler("")

	req := httptest.NewRequest(http.MethodPost, "http://example.com/v1/auth/login", nil)
	req.Host = "example.com"
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusPermanentRedirect {
		t.Fatalf("POST status = %d, want %d", rec.Code, http.StatusPermanentRedirect)
	}
	want := "https://example.com/v1/auth/login"
	if got := rec.Header().Get("Location"); got != want {
		t.Errorf("Location = %q, want %q", got, want)
	}
}

func TestNewRedirectHandler_NeverReachesAPIHandler(t *testing.T) {
	// The real HTTP redirect listener in main.go never wires an API
	// handler in at all - its Handler is exclusively this redirect (or,
	// in acme mode, the ACME challenge handler wrapping it). This test
	// documents that the redirect handler itself unconditionally
	// redirects and never dispatches based on path or method, so a
	// body-bearing request like POST /v1/auth/login is neither read nor
	// acted upon, regardless of what else might share the listener.
	redirect := newRedirectHandler("")

	for _, path := range []string{"/v1/auth/login", "/v1/admin/backup", "/v1/blobs"} {
		req := httptest.NewRequest(http.MethodPost, "http://example.com"+path, nil)
		req.Host = "example.com"
		rec := httptest.NewRecorder()
		redirect.ServeHTTP(rec, req)

		if rec.Code != http.StatusPermanentRedirect {
			t.Errorf("POST %s: status = %d, want %d", path, rec.Code, http.StatusPermanentRedirect)
		}
		if got, want := rec.Header().Get("Location"), "https://example.com"+path; got != want {
			t.Errorf("POST %s: Location = %q, want %q", path, got, want)
		}
	}
}

func TestACMEHTTPHandler_NonChallengePathFallsBackToRedirect(t *testing.T) {
	manager := &autocert.Manager{
		Cache:      autocert.DirCache(t.TempDir()),
		HostPolicy: autocert.HostWhitelist("example.com"),
	}
	handler := manager.HTTPHandler(newRedirectHandler(""))

	req := httptest.NewRequest(http.MethodPost, "http://example.com/v1/auth/login", nil)
	req.Host = "example.com"
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusPermanentRedirect {
		t.Fatalf("status = %d, want %d (redirect, not an API response)", rec.Code, http.StatusPermanentRedirect)
	}
}

func TestACMEHTTPHandler_ChallengePathNotRedirected(t *testing.T) {
	manager := &autocert.Manager{
		Cache:      autocert.DirCache(t.TempDir()),
		HostPolicy: autocert.HostWhitelist("example.com"),
	}
	handler := manager.HTTPHandler(newRedirectHandler(""))

	req := httptest.NewRequest(http.MethodGet, "http://example.com/.well-known/acme-challenge/some-token", nil)
	req.Host = "example.com"
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	// No challenge has actually been issued in this test, so autocert
	// answers 404 for the unknown token - the point being it does NOT
	// answer 308/Location (i.e. it did not treat this path as needing a
	// redirect), and it never reaches an application handler either way.
	if rec.Code == http.StatusPermanentRedirect {
		t.Error("ACME challenge path must not be redirected")
	}
	if loc := rec.Header().Get("Location"); loc != "" {
		t.Errorf("ACME challenge path must not carry a redirect Location, got %q", loc)
	}
}

func TestHTTPSPort(t *testing.T) {
	cases := map[string]string{
		":8443":               "8443",
		"vps.example.com:443": "443",
		"127.0.0.1:9443":      "9443",
		"no-port-here":        "",
	}
	for addr, want := range cases {
		if got := httpsPort(addr); got != want {
			t.Errorf("httpsPort(%q) = %q, want %q", addr, got, want)
		}
	}
}
