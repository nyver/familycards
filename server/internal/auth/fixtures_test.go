package auth_test

import (
	"encoding/base64"
	"encoding/json"
)

func b64(n int) string {
	b := make([]byte, n)
	for i := range b {
		b[i] = byte(i*7 + n) // deterministic filler, uniqueness not required by these tests
	}
	return base64.StdEncoding.EncodeToString(b)
}

func kdfParams() json.RawMessage {
	return json.RawMessage(`{"m":65536,"t":3,"p":1}`)
}

type deviceBody struct {
	ID       string `json:"id,omitempty"`
	Name     string `json:"name"`
	Platform string `json:"platform"`
}

type recoveryBody struct {
	WrappedVaultKey string          `json:"wrapped_vault_key"`
	WrapNonce       string          `json:"wrap_nonce"`
	KDFSalt         string          `json:"kdf_salt"`
	KDFParams       json.RawMessage `json:"kdf_params"`
	Verifier        string          `json:"verifier"`
}

type bootstrapBody struct {
	Login           string          `json:"login"`
	DisplayName     string          `json:"display_name"`
	Password        string          `json:"password"`
	KDFSalt         string          `json:"kdf_salt"`
	KDFParams       json.RawMessage `json:"kdf_params"`
	WrappedVaultKey string          `json:"wrapped_vault_key"`
	WrapNonce       string          `json:"wrap_nonce"`
	Recovery        recoveryBody    `json:"recovery"`
	Device          deviceBody      `json:"device"`
}

func validBootstrap(login string) bootstrapBody {
	return bootstrapBody{
		Login:           login,
		DisplayName:     "Test User",
		Password:        "correct horse battery staple",
		KDFSalt:         b64(16),
		KDFParams:       kdfParams(),
		WrappedVaultKey: b64(48),
		WrapNonce:       b64(24),
		Recovery: recoveryBody{
			WrappedVaultKey: b64(48),
			WrapNonce:       b64(24),
			KDFSalt:         b64(16),
			KDFParams:       kdfParams(),
			Verifier:        "test recovery phrase verifier",
		},
		Device: deviceBody{Name: "Test Device", Platform: "android"},
	}
}
