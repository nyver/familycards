package membership_test

import (
	"context"
	"net/http/httptest"
	"path/filepath"
	"testing"
	"time"

	"familycards/server/internal/auth"
	"familycards/server/internal/httpapi"
	"familycards/server/internal/membership"
	"familycards/server/internal/migrations"
	"familycards/server/internal/ratelimit"
	"familycards/server/internal/storage"
)

const testBootstrapToken = "test-bootstrap-token"
const testJWTSecret = "0123456789abcdef0123456789abcdef"

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
	authHandlers := auth.NewHandlers(db, tokens, testBootstrapToken, []byte(testJWTSecret))
	membershipHandlers := membership.NewHandlers(db, tokens)

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
		RequireAuth:    mw.RequireAuth,
		AllowInsecure:  true,
		AuthLimiter:    ratelimit.New(100000, time.Hour),
		GeneralLimiter: ratelimit.New(100000, time.Hour),
	})

	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	return srv, db
}
