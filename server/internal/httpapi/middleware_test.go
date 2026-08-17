package httpapi_test

import (
	"bytes"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"familycards/server/internal/httpapi"
)

func readAllHandler(w http.ResponseWriter, r *http.Request) {
	_, err := io.ReadAll(r.Body)
	if err != nil {
		w.WriteHeader(http.StatusRequestEntityTooLarge)
		return
	}
	w.WriteHeader(http.StatusOK)
}

func TestLimitBody_RejectsOversizedDefaultRequest(t *testing.T) {
	handler := httpapi.LimitBody(http.HandlerFunc(readAllHandler))

	oversized := bytes.Repeat([]byte("a"), (1<<20)+1)
	req := httptest.NewRequest(http.MethodPost, "/v1/sync/push", bytes.NewReader(oversized))
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusRequestEntityTooLarge {
		t.Errorf("status = %d, want 413 for body over the 1 MiB default limit", w.Code)
	}
}

func TestLimitBody_AllowsLargerBlobUpload(t *testing.T) {
	handler := httpapi.LimitBody(http.HandlerFunc(readAllHandler))

	// 2 MiB is over the default 1 MiB limit but under the 8 MiB blob limit.
	body := bytes.Repeat([]byte("a"), 2<<20)
	req := httptest.NewRequest(http.MethodPost, "/v1/blobs", bytes.NewReader(body))
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("status = %d, want 200 for a 2 MiB blob upload", w.Code)
	}
}

func TestRecover_CatchesPanic(t *testing.T) {
	handler := httpapi.Recover(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		panic("boom")
	}))

	req := httptest.NewRequest(http.MethodGet, "/anything", nil)
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Errorf("status after panic = %d, want 500", w.Code)
	}
}

func TestResolveClientIP_UntrustedProxyIgnoresHeader(t *testing.T) {
	var seen string
	inner := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seen = httpapi.ClientIP(r)
	})
	handler := httpapi.ResolveClientIP(false)(inner)

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.RemoteAddr = "10.0.0.5:12345"
	req.Header.Set("X-Forwarded-For", "1.2.3.4")
	handler.ServeHTTP(httptest.NewRecorder(), req)

	if seen != "10.0.0.5" {
		t.Errorf("ClientIP = %q, want the real peer address when the proxy is untrusted", seen)
	}
}

func TestResolveClientIP_TrustedProxyUsesHeader(t *testing.T) {
	var seen string
	inner := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seen = httpapi.ClientIP(r)
	})
	handler := httpapi.ResolveClientIP(true)(inner)

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.RemoteAddr = "10.0.0.5:12345"
	req.Header.Set("X-Forwarded-For", "1.2.3.4, 10.0.0.5")
	handler.ServeHTTP(httptest.NewRecorder(), req)

	if seen != "1.2.3.4" {
		t.Errorf("ClientIP = %q, want the first forwarded address when the proxy is trusted", seen)
	}
}
