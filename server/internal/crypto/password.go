// Package crypto provides the server-side password hashing (argon2id) and
// random generation primitives. The server never derives or sees the
// client's vault key encryption key (KEK) - it only authenticates passwords.
package crypto

import (
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"fmt"
	"strings"

	"golang.org/x/crypto/argon2"
)

// PasswordParams are the argon2id parameters used to hash passwords for
// authentication. These are independent from the client's KEK derivation
// parameters, which use a different salt.
type PasswordParams struct {
	Memory  uint32 // KiB
	Time    uint32
	Threads uint8
}

// DefaultPasswordParams matches the spec: m=64 MiB, t=3, p=1.
var DefaultPasswordParams = PasswordParams{Memory: 64 * 1024, Time: 3, Threads: 1}

const saltLen = 16
const keyLen = 32

// HashPassword produces a PHC-formatted argon2id string for password,
// generating a fresh random salt.
func HashPassword(password string) (string, error) {
	salt := make([]byte, saltLen)
	if _, err := rand.Read(salt); err != nil {
		return "", fmt.Errorf("crypto: generate salt: %w", err)
	}
	return hashWithSalt(password, salt, DefaultPasswordParams), nil
}

func hashWithSalt(password string, salt []byte, p PasswordParams) string {
	hash := argon2.IDKey([]byte(password), salt, p.Time, p.Memory, p.Threads, keyLen)
	return fmt.Sprintf("$argon2id$v=19$m=%d,t=%d,p=%d$%s$%s",
		p.Memory, p.Time, p.Threads,
		base64.RawStdEncoding.EncodeToString(salt),
		base64.RawStdEncoding.EncodeToString(hash),
	)
}

// VerifyPassword checks password against a PHC-formatted argon2id hash in
// constant time.
func VerifyPassword(password, encoded string) (bool, error) {
	parts := strings.Split(encoded, "$")
	// ["", "argon2id", "v=19", "m=..,t=..,p=..", "salt", "hash"]
	if len(parts) != 6 || parts[1] != "argon2id" {
		return false, fmt.Errorf("crypto: malformed password hash")
	}

	var m, t uint32
	var p uint8
	if _, err := fmt.Sscanf(parts[3], "m=%d,t=%d,p=%d", &m, &t, &p); err != nil {
		return false, fmt.Errorf("crypto: malformed password hash params: %w", err)
	}

	salt, err := base64.RawStdEncoding.DecodeString(parts[4])
	if err != nil {
		return false, fmt.Errorf("crypto: malformed password hash salt: %w", err)
	}
	want, err := base64.RawStdEncoding.DecodeString(parts[5])
	if err != nil {
		return false, fmt.Errorf("crypto: malformed password hash digest: %w", err)
	}

	got := argon2.IDKey([]byte(password), salt, t, m, p, uint32(len(want)))
	return subtle.ConstantTimeCompare(got, want) == 1, nil
}

// RandomBytes returns n cryptographically random bytes.
func RandomBytes(n int) ([]byte, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return nil, fmt.Errorf("crypto: random bytes: %w", err)
	}
	return b, nil
}

// SHA256Hex returns the lowercase hex-encoded sha256 digest of data.
func SHA256Hex(data []byte) string {
	sum := sha256.Sum256(data)
	return fmt.Sprintf("%x", sum)
}

// HMACSHA256Hex returns the lowercase hex-encoded HMAC-SHA256 of message
// keyed by key.
func HMACSHA256Hex(key, message []byte) string {
	mac := hmacSHA256(key, message)
	return fmt.Sprintf("%x", mac)
}

// HMACSHA256 returns the raw HMAC-SHA256 digest of message keyed by key.
// Used to derive deterministic fake KDF salts for prelogin so unknown
// logins are indistinguishable from known ones.
func HMACSHA256(key, message []byte) []byte {
	return hmacSHA256(key, message)
}

// ConstantTimeEqual compares two byte slices in constant time.
func ConstantTimeEqual(a, b []byte) bool {
	if len(a) != len(b) {
		return false
	}
	return subtle.ConstantTimeCompare(a, b) == 1
}
