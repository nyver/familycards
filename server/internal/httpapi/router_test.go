package httpapi_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"familycards/server/internal/httpapi"
	"familycards/server/internal/migrations"
	"familycards/server/internal/ratelimit"
	"familycards/server/internal/storage"
)

func newTestRouter(t *testing.T, allowInsecure bool, authRate, generalRate int) http.Handler {
	t.Helper()
	dbPath := filepath.Join(t.TempDir(), "wallet.db")
	db, err := storage.Open(dbPath)
	if err != nil {
		t.Fatalf("storage.Open: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	if err := migrations.Apply(context.Background(), db.Write); err != nil {
		t.Fatalf("migrations.Apply: %v", err)
	}

	return httpapi.Router(httpapi.RouterConfig{
		ReadDB: db.Read,
		Auth: httpapi.AuthEndpoints{
			Bootstrap:        func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusCreated) },
			Prelogin:         func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) },
			Login:            func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) },
			Refresh:          func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) },
			Logout:           func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusNoContent) },
			ChangePassword:   func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusNoContent) },
			Me:               func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) },
			RecoveryPrelogin: func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) },
			RecoveryRedeem:   func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) },
		},
		RequireAuth: func(next http.Handler) http.Handler {
			return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(http.StatusUnauthorized)
			})
		},
		AllowInsecure:  allowInsecure,
		AuthLimiter:    ratelimit.New(authRate, time.Hour),
		GeneralLimiter: ratelimit.New(generalRate, time.Hour),
	})
}

func TestHealthEndpoint(t *testing.T) {
	handler := newTestRouter(t, true, 1000, 1000)
	srv := httptest.NewServer(handler)
	defer srv.Close()

	resp, err := http.Get(srv.URL + "/v1/health")
	if err != nil {
		t.Fatalf("GET /v1/health: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Errorf("status = %d, want 200", resp.StatusCode)
	}
}

func TestEnforceHTTPS_Rejected(t *testing.T) {
	handler := newTestRouter(t, false, 1000, 1000)
	srv := httptest.NewServer(handler)
	defer srv.Close()

	resp, err := http.Get(srv.URL + "/v1/health")
	if err != nil {
		t.Fatalf("GET /v1/health: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("status without X-Forwarded-Proto = %d, want 400", resp.StatusCode)
	}
}

func TestEnforceHTTPS_AcceptedWithHeader(t *testing.T) {
	handler := newTestRouter(t, false, 1000, 1000)
	srv := httptest.NewServer(handler)
	defer srv.Close()

	req, _ := http.NewRequest(http.MethodGet, srv.URL+"/v1/health", nil)
	req.Header.Set("X-Forwarded-Proto", "https")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("GET /v1/health: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Errorf("status with X-Forwarded-Proto=https = %d, want 200", resp.StatusCode)
	}
}

func TestRateLimit_AuthPathStricter(t *testing.T) {
	handler := newTestRouter(t, true, 2, 1000)
	srv := httptest.NewServer(handler)
	defer srv.Close()

	body := `{"login":"a","password":"b","device":{"name":"d","platform":"android"}}`
	for i := 0; i < 2; i++ {
		resp, err := http.Post(srv.URL+"/v1/auth/login", "application/json", strings.NewReader(body))
		if err != nil {
			t.Fatalf("POST /v1/auth/login: %v", err)
		}
		resp.Body.Close()
	}

	resp, err := http.Post(srv.URL+"/v1/auth/login", "application/json", strings.NewReader(body))
	if err != nil {
		t.Fatalf("POST /v1/auth/login: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusTooManyRequests {
		t.Errorf("3rd auth request status = %d, want 429", resp.StatusCode)
	}
	if resp.Header.Get("Retry-After") == "" {
		t.Error("expected Retry-After header on 429")
	}
}

func TestRequireAuth_AppliedToProtectedRoutes(t *testing.T) {
	handler := newTestRouter(t, true, 1000, 1000)
	srv := httptest.NewServer(handler)
	defer srv.Close()

	resp, err := http.Get(srv.URL + "/v1/me")
	if err != nil {
		t.Fatalf("GET /v1/me: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("GET /v1/me without auth = %d, want 401 (RequireAuth stub should trigger)", resp.StatusCode)
	}
}
