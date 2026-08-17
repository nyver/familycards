package auth

import (
	"database/sql"
	"net/http"
	"strings"

	"familycards/server/internal/httpapi"
)

// Middleware bundles the dependencies needed to authenticate requests.
type Middleware struct {
	tokens *TokenManager
	readDB *sql.DB
}

// NewMiddleware builds a Middleware backed by tokens for verification and
// readDB for the device/user revocation checks that a JWT signature alone
// cannot express (revocation happens server-side, after tokens are issued).
func NewMiddleware(tokens *TokenManager, readDB *sql.DB) *Middleware {
	return &Middleware{tokens: tokens, readDB: readDB}
}

// RequireAuth validates the Authorization: Bearer header, rejects tokens
// belonging to revoked devices or disabled users, and attaches the
// resulting Identity to the request context.
func (m *Middleware) RequireAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		const prefix = "Bearer "
		if !strings.HasPrefix(header, prefix) {
			httpapi.WriteError(w, httpapi.ErrUnauthorized("missing bearer token"))
			return
		}
		tokenString := strings.TrimPrefix(header, prefix)

		claims, err := m.tokens.ParseAccessToken(tokenString)
		if err != nil {
			httpapi.WriteError(w, httpapi.ErrUnauthorized("invalid or expired token"))
			return
		}

		ctx := r.Context()
		device, err := GetDeviceByID(ctx, m.readDB, claims.DeviceID)
		if err != nil || device.Revoked || device.UserID != claims.UserID {
			httpapi.WriteError(w, httpapi.ErrUnauthorized("device access revoked"))
			return
		}

		user, err := GetUserByID(ctx, m.readDB, claims.UserID)
		if err != nil || user.Disabled || user.VaultID != claims.VaultID {
			httpapi.WriteError(w, httpapi.ErrUnauthorized("account access revoked"))
			return
		}

		id := Identity{UserID: claims.UserID, VaultID: claims.VaultID, DeviceID: claims.DeviceID}
		next.ServeHTTP(w, r.WithContext(withIdentity(ctx, id)))
	})
}
