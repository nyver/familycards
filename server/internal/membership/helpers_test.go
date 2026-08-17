package membership_test

import (
	"bytes"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"testing"
	"time"
)

func testHTTPClient() *http.Client {
	return &http.Client{Timeout: 5 * time.Second}
}

func doJSON(t *testing.T, method, url string, headers map[string]string, body any) *http.Response {
	t.Helper()

	var reader *bytes.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			t.Fatalf("marshal body: %v", err)
		}
		reader = bytes.NewReader(b)
	} else {
		reader = bytes.NewReader(nil)
	}

	req, err := http.NewRequest(method, url, reader)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	for k, v := range headers {
		req.Header.Set(k, v)
	}

	resp, err := testHTTPClient().Do(req)
	if err != nil {
		t.Fatalf("%s %s: %v", method, url, err)
	}
	return resp
}

func decodeJSON(t *testing.T, resp *http.Response, v any) {
	t.Helper()
	defer resp.Body.Close()
	if err := json.NewDecoder(resp.Body).Decode(v); err != nil {
		t.Fatalf("decode response body: %v", err)
	}
}

func b64(n int) string {
	b := make([]byte, n)
	for i := range b {
		b[i] = byte(i*7 + n)
	}
	return base64.StdEncoding.EncodeToString(b)
}

func kdfParams() json.RawMessage {
	return json.RawMessage(`{"m":65536,"t":3,"p":1}`)
}

func sha256Hex(s string) string {
	sum := sha256.Sum256([]byte(s))
	return hex.EncodeToString(sum[:])
}

type deviceBody struct {
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
