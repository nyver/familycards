package auth_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"
	"time"

	"familycards/server/internal/auth"
	"familycards/server/internal/httpapi"
	"familycards/server/internal/migrations"
	"familycards/server/internal/ratelimit"
	"familycards/server/internal/storage"
)

const testBootstrapToken = "test-bootstrap-token"
const testJWTSecret = "0123456789abcdef0123456789abcdef"

// newTestServer spins up a full httptest.Server backed by a temp-file
// SQLite database with migrations applied, wired through the real router
// and middleware stack (rate limiting excepted, generously sized so it
// never interferes with tests).
func newTestServer(t *testing.T) (*httptest.Server, *storage.DB) {
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

	tokens := auth.NewTokenManager([]byte(testJWTSecret))
	mw := auth.NewMiddleware(tokens, db.Read)
	h := auth.NewHandlers(db, tokens, testBootstrapToken, []byte(testJWTSecret))

	handler := httpapi.Router(httpapi.RouterConfig{
		ReadDB: db.Read,
		Auth: httpapi.AuthEndpoints{
			Bootstrap:        h.Bootstrap,
			Prelogin:         h.Prelogin,
			Login:            h.Login,
			Refresh:          h.Refresh,
			Logout:           h.Logout,
			ChangePassword:   h.ChangePassword,
			Me:               h.Me,
			RecoveryPrelogin: h.RecoveryPrelogin,
			RecoveryRedeem:   h.RecoveryRedeem,
		},
		RequireAuth:    mw.RequireAuth,
		AllowInsecure:  true,
		AuthLimiter:    ratelimit.New(100000, time.Hour),
		GeneralLimiter: ratelimit.New(100000, time.Hour),
	})

	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	return srv, db
}

func testHTTPClient() *http.Client {
	return &http.Client{Timeout: 5 * time.Second}
}
