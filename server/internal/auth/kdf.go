package auth

import (
	"fmt"

	"familycards/server/internal/crypto"
)

// DefaultKDFParams is the JSON encoding of the Argon2id parameters clients
// must use to derive KEK: m=64 MiB, t=3, p=1. Real per-user rows store their
// own kdf_params, but new accounts and fake prelogin responses use this.
const DefaultKDFParams = `{"m":65536,"t":3,"p":1}`

const fakeSaltLen = 16

// FakeKDFSalt returns a deterministic pseudo-salt for prelogin responses to
// unknown logins: HMAC(serverSecret, login) truncated to the real salt
// length. Deterministic (not random) so repeated prelogin calls for the same
// unknown login return the same value, which would otherwise itself be an
// oracle for account existence.
func FakeKDFSalt(serverSecret []byte, login string) []byte {
	return crypto.HMACSHA256(serverSecret, []byte(login))[:fakeSaltLen]
}

// FakeRecoveryKDFSalt is FakeKDFSalt's counterpart for the recovery-phrase
// prelogin endpoint. Domain-separated ("recovery:" prefix) so it never
// collides with the password fake salt for the same login - not a security
// requirement by itself, just hygiene, since the two endpoints authenticate
// against different secrets.
func FakeRecoveryKDFSalt(serverSecret []byte, login string) []byte {
	return crypto.HMACSHA256(serverSecret, []byte("recovery:"+login))[:fakeSaltLen]
}

const (
	fakeWrapNonceLen  = 24 // XChaCha20 nonce length
	fakeWrapCipherLen = 48 // 32-byte VK + 16-byte Poly1305 tag
)

// FakeRecoveryWrapNonce and FakeRecoveryWrappedVaultKey return deterministic
// pseudo-random bytes, the same shape and length as a real recovery wrap,
// for unknown logins. Neither decrypts to anything - they exist purely so
// POST /v1/auth/recovery/prelogin cannot be used to distinguish a known
// login from an unknown one by response shape.
func FakeRecoveryWrapNonce(serverSecret []byte, login string) []byte {
	return expandHMAC(serverSecret, "recovery-nonce:"+login, fakeWrapNonceLen)
}

func FakeRecoveryWrappedVaultKey(serverSecret []byte, login string) []byte {
	return expandHMAC(serverSecret, "recovery-wrap:"+login, fakeWrapCipherLen)
}

// expandHMAC produces length pseudo-random bytes by concatenating
// HMAC-SHA256(secret, label:0), HMAC-SHA256(secret, label:1), ... - a
// simple counter-mode expansion, sufficient here since the output only
// needs to be indistinguishable from ciphertext, not itself secret.
func expandHMAC(secret []byte, label string, length int) []byte {
	out := make([]byte, 0, length)
	for i := 0; len(out) < length; i++ {
		out = append(out, crypto.HMACSHA256(secret, []byte(fmt.Sprintf("%s:%d", label, i)))...)
	}
	return out[:length]
}
