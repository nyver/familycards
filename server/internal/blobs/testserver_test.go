package blobs_test

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"
	"time"

	"familycards/server/internal/auth"
	"familycards/server/internal/blobs"
	"familycards/server/internal/httpapi"
	"familycards/server/internal/migrations"
	"familycards/server/internal/ratelimit"
	"familycards/server/internal/storage"
)

const testBootstrapToken = "test-bootstrap-token"
const testJWTSecret = "0123456789abcdef0123456789abcdef"

func newTestServer(t *testing.T) (*httptest.Server, *storage.DB, *blobs.Store) {
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

	store := blobs.NewStore(t.TempDir())

	tokens := auth.NewTokenManager([]byte(testJWTSecret))
	mw := auth.NewMiddleware(tokens, db.Read)
	authHandlers := auth.NewHandlers(db, tokens, testBootstrapToken, []byte(testJWTSecret))
	blobHandlers := blobs.NewHandlers(db, store)

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
		Blobs: httpapi.BlobEndpoints{
			Upload: blobHandlers.Upload,
			Get:    blobHandlers.Get,
		},
		RequireAuth:    mw.RequireAuth,
		AllowInsecure:  true,
		AuthLimiter:    ratelimit.New(1000000, time.Hour),
		GeneralLimiter: ratelimit.New(1000000, time.Hour),
	})

	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	return srv, db, store
}

func testHTTPClient() *http.Client {
	return &http.Client{Timeout: 30 * time.Second}
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

func b64(n int, seed byte) string {
	b := make([]byte, n)
	for i := range b {
		b[i] = byte(i*7) + seed
	}
	return base64.StdEncoding.EncodeToString(b)
}

func kdfParams() json.RawMessage {
	return json.RawMessage(`{"m":65536,"t":3,"p":1}`)
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

type bootstrapResp struct {
	UserID       string `json:"user_id"`
	VaultID      string `json:"vault_id"`
	DeviceID     string `json:"device_id"`
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
}

func bootstrap(t *testing.T, srvURL, login string) bootstrapResp {
	t.Helper()
	body := bootstrapBody{
		Login:           login,
		DisplayName:     "Test User",
		Password:        "correct horse battery staple",
		KDFSalt:         b64(16, 1),
		KDFParams:       kdfParams(),
		WrappedVaultKey: b64(48, 2),
		WrapNonce:       b64(24, 3),
		Recovery: recoveryBody{
			WrappedVaultKey: b64(48, 4),
			WrapNonce:       b64(24, 5),
			KDFSalt:         b64(16, 6),
			KDFParams:       kdfParams(),
			Verifier:        "test recovery phrase verifier",
		},
		Device: deviceBody{Name: "Test Device", Platform: "android"},
	}
	resp := doJSON(t, http.MethodPost, srvURL+"/v1/auth/bootstrap", map[string]string{"X-Bootstrap-Token": testBootstrapToken}, body)
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("bootstrap status = %d, want 201", resp.StatusCode)
	}
	var b bootstrapResp
	decodeJSON(t, resp, &b)
	return b
}

func authHeader(token string) map[string]string {
	return map[string]string{"Authorization": "Bearer " + token}
}

func sha256Hex(data []byte) string {
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}

func uploadBlob(t *testing.T, srvURL, token string, data []byte) *http.Response {
	t.Helper()
	req, err := http.NewRequest(http.MethodPost, srvURL+"/v1/blobs", bytes.NewReader(data))
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("X-Blob-Id", sha256Hex(data))
	req.Header.Set("Content-Type", "application/octet-stream")
	resp, err := testHTTPClient().Do(req)
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	return resp
}
