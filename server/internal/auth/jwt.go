// Package auth implements account and session lifecycle: bootstrap, login,
// prelogin, token refresh with rotation, logout, and password change. It
// also provides the bearer-token authentication middleware used by every
// other protected package.
package auth

import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"familycards/server/internal/crypto"
)

// AccessTokenTTL and RefreshTokenTTL are fixed by the sync protocol spec.
const (
	AccessTokenTTL  = 15 * time.Minute
	RefreshTokenTTL = 30 * 24 * time.Hour
)

const refreshTokenBytes = 32

// ErrInvalidToken is returned for any access token that fails to parse or
// validate, without distinguishing the specific cause (expired, malformed,
// wrong signature) to callers outside this package.
var ErrInvalidToken = errors.New("auth: invalid access token")

// Claims is the JWT payload for access tokens.
type Claims struct {
	UserID   string `json:"uid"`
	VaultID  string `json:"vid"`
	DeviceID string `json:"did"`
	jwt.RegisteredClaims
}

// TokenManager issues and verifies access tokens and generates refresh
// tokens. It is safe for concurrent use.
type TokenManager struct {
	secret []byte
}

// NewTokenManager builds a TokenManager signing with secret.
func NewTokenManager(secret []byte) *TokenManager {
	return &TokenManager{secret: secret}
}

// IssueAccessToken returns a signed JWT valid for AccessTokenTTL.
func (tm *TokenManager) IssueAccessToken(userID, vaultID, deviceID string) (string, error) {
	now := time.Now()
	claims := Claims{
		UserID:   userID,
		VaultID:  vaultID,
		DeviceID: deviceID,
		RegisteredClaims: jwt.RegisteredClaims{
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(AccessTokenTTL)),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString(tm.secret)
	if err != nil {
		return "", fmt.Errorf("auth: sign access token: %w", err)
	}
	return signed, nil
}

// ParseAccessToken validates the signature and expiry of tokenString and
// returns its claims.
func (tm *TokenManager) ParseAccessToken(tokenString string) (*Claims, error) {
	claims := &Claims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, ErrInvalidToken
		}
		return tm.secret, nil
	})
	if err != nil || !token.Valid {
		return nil, ErrInvalidToken
	}
	return claims, nil
}

// NewRefreshToken generates a fresh opaque refresh token and returns both
// the raw token (sent to the client once) and the hex sha256 hash stored in
// devices.refresh_hash.
func NewRefreshToken() (raw string, hash string, err error) {
	b, err := crypto.RandomBytes(refreshTokenBytes)
	if err != nil {
		return "", "", fmt.Errorf("auth: generate refresh token: %w", err)
	}
	raw = base64.RawURLEncoding.EncodeToString(b)
	hash = HashRefreshToken(raw)
	return raw, hash, nil
}

// HashRefreshToken returns the hex sha256 digest of a raw refresh token, the
// form stored server-side and compared on refresh/logout.
func HashRefreshToken(raw string) string {
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}
