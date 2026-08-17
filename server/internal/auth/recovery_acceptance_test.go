package auth_test

import (
	"encoding/base64"
	"net/http"
	"testing"
)

type recoveryPreloginResp struct {
	KDFSalt         string `json:"kdf_salt"`
	WrappedVaultKey string `json:"wrapped_vault_key"`
	WrapNonce       string `json:"wrap_nonce"`
}

func TestAcceptance_RecoveryPrelogin_ReturnsUsableWrapForKnownLogin(t *testing.T) {
	srv, _ := newTestServer(t)
	doJSON(t, http.MethodPost, srv.URL+"/v1/auth/bootstrap", map[string]string{"X-Bootstrap-Token": testBootstrapToken}, validBootstrap("alice")).Body.Close()

	resp := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/recovery/prelogin", nil, map[string]string{"login": "alice"})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("recovery prelogin status = %d, want 200", resp.StatusCode)
	}
	var got recoveryPreloginResp
	decodeJSON(t, resp, &got)

	if got.KDFSalt == "" || got.WrappedVaultKey == "" || got.WrapNonce == "" {
		t.Fatalf("expected non-empty kdf_salt, wrapped_vault_key, and wrap_nonce, got %+v", got)
	}

	wrapBytes, err := base64.StdEncoding.DecodeString(got.WrappedVaultKey)
	if err != nil {
		t.Fatalf("wrapped_vault_key is not valid base64: %v", err)
	}
	nonceBytes, err := base64.StdEncoding.DecodeString(got.WrapNonce)
	if err != nil {
		t.Fatalf("wrap_nonce is not valid base64: %v", err)
	}
	if len(wrapBytes) != 48 {
		t.Errorf("wrapped_vault_key length = %d, want 48 (32-byte VK + 16-byte tag)", len(wrapBytes))
	}
	if len(nonceBytes) != 24 {
		t.Errorf("wrap_nonce length = %d, want 24", len(nonceBytes))
	}

	// validBootstrap's recovery object sends WrappedVaultKey: b64(48) and
	// WrapNonce: b64(24) - prelogin must return exactly what was stored.
	if got.WrappedVaultKey != b64(48) {
		t.Errorf("wrapped_vault_key = %q, want the value bootstrap originally sent (%q)", got.WrappedVaultKey, b64(48))
	}
	if got.WrapNonce != b64(24) {
		t.Errorf("wrap_nonce = %q, want the value bootstrap originally sent (%q)", got.WrapNonce, b64(24))
	}
}

func mustB64Decode(t *testing.T, s string) []byte {
	t.Helper()
	b, err := base64.StdEncoding.DecodeString(s)
	if err != nil {
		t.Fatalf("decode: %v", err)
	}
	return b
}

func TestAcceptance_RecoveryPrelogin_KnownAndUnknownLogin(t *testing.T) {
	srv, _ := newTestServer(t)
	doJSON(t, http.MethodPost, srv.URL+"/v1/auth/bootstrap", map[string]string{"X-Bootstrap-Token": testBootstrapToken}, validBootstrap("alice")).Body.Close()

	known := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/recovery/prelogin", nil, map[string]string{"login": "alice"})
	if known.StatusCode != http.StatusOK {
		t.Fatalf("recovery prelogin for known login status = %d, want 200", known.StatusCode)
	}
	var knownResp recoveryPreloginResp
	decodeJSON(t, known, &knownResp)
	if knownResp.KDFSalt == "" {
		t.Error("expected a non-empty kdf_salt for a known login")
	}

	unknown1 := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/recovery/prelogin", nil, map[string]string{"login": "nobody"})
	var u1 recoveryPreloginResp
	decodeJSON(t, unknown1, &u1)

	unknown2 := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/recovery/prelogin", nil, map[string]string{"login": "nobody"})
	var u2 recoveryPreloginResp
	decodeJSON(t, unknown2, &u2)

	if u1.KDFSalt != u2.KDFSalt {
		t.Error("fake recovery salt should be deterministic for the same unknown login")
	}
	if u1.WrappedVaultKey != u2.WrappedVaultKey || u1.WrapNonce != u2.WrapNonce {
		t.Error("fake wrap should be deterministic for the same unknown login")
	}
	if len(mustB64Decode(t, u1.WrappedVaultKey)) != 48 {
		t.Errorf("fake wrapped_vault_key length = %d, want 48", len(mustB64Decode(t, u1.WrappedVaultKey)))
	}
	if len(mustB64Decode(t, u1.WrapNonce)) != 24 {
		t.Errorf("fake wrap_nonce length = %d, want 24", len(mustB64Decode(t, u1.WrapNonce)))
	}
	if u1.KDFSalt == knownResp.KDFSalt {
		t.Error("fake salt should not coincidentally equal the real salt in this test")
	}
}

func TestAcceptance_RecoveryRedeem_CorrectVerifierResetsPassword(t *testing.T) {
	srv, _ := newTestServer(t)
	bResp := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/bootstrap", map[string]string{"X-Bootstrap-Token": testBootstrapToken}, validBootstrap("alice"))
	var bootstrap struct {
		RefreshToken string `json:"refresh_token"`
	}
	decodeJSON(t, bResp, &bootstrap)

	redeemResp := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/recovery/redeem", nil, map[string]any{
		"login":             "alice",
		"verifier":          "test recovery phrase verifier",
		"new_password":      "a brand new recovered password",
		"kdf_salt":          b64(16),
		"kdf_params":        kdfParams(),
		"wrapped_vault_key": b64(48),
		"wrap_nonce":        b64(24),
		"device":            map[string]string{"name": "Recovery Device", "platform": "android"},
	})
	if redeemResp.StatusCode != http.StatusOK {
		t.Fatalf("recovery redeem status = %d, want 200", redeemResp.StatusCode)
	}
	var redeemed struct {
		AccessToken string `json:"access_token"`
	}
	decodeJSON(t, redeemResp, &redeemed)
	if redeemed.AccessToken == "" {
		t.Error("expected an access token from a successful recovery redeem")
	}

	// New password works.
	loginResp := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/login", nil, map[string]any{
		"login":    "alice",
		"password": "a brand new recovered password",
		"device":   map[string]string{"name": "D", "platform": "android"},
	})
	if loginResp.StatusCode != http.StatusOK {
		t.Fatalf("login with new password status = %d, want 200", loginResp.StatusCode)
	}
	loginResp.Body.Close()

	// Old password no longer works.
	oldLoginResp := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/login", nil, map[string]any{
		"login":    "alice",
		"password": "correct horse battery staple",
		"device":   map[string]string{"name": "D2", "platform": "android"},
	})
	if oldLoginResp.StatusCode != http.StatusUnauthorized {
		t.Errorf("login with old password after recovery status = %d, want 401", oldLoginResp.StatusCode)
	}
	oldLoginResp.Body.Close()

	// The pre-recovery device's refresh token is revoked.
	refreshResp := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/refresh", nil, map[string]string{"refresh_token": bootstrap.RefreshToken})
	if refreshResp.StatusCode != http.StatusUnauthorized {
		t.Errorf("refresh with pre-recovery token status = %d, want 401", refreshResp.StatusCode)
	}
	refreshResp.Body.Close()
}

func TestAcceptance_RecoveryRedeem_WrongVerifierRejectedAndNothingChanges(t *testing.T) {
	srv, _ := newTestServer(t)
	doJSON(t, http.MethodPost, srv.URL+"/v1/auth/bootstrap", map[string]string{"X-Bootstrap-Token": testBootstrapToken}, validBootstrap("alice")).Body.Close()

	redeemResp := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/recovery/redeem", nil, map[string]any{
		"login":             "alice",
		"verifier":          "not the right phrase at all",
		"new_password":      "attacker chosen password",
		"kdf_salt":          b64(16),
		"kdf_params":        kdfParams(),
		"wrapped_vault_key": b64(48),
		"wrap_nonce":        b64(24),
		"device":            map[string]string{"name": "Attacker Device", "platform": "android"},
	})
	if redeemResp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("recovery redeem with wrong verifier status = %d, want 401", redeemResp.StatusCode)
	}
	redeemResp.Body.Close()

	// Original password still works; nothing was changed.
	loginResp := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/login", nil, map[string]any{
		"login":    "alice",
		"password": "correct horse battery staple",
		"device":   map[string]string{"name": "D", "platform": "android"},
	})
	if loginResp.StatusCode != http.StatusOK {
		t.Fatalf("login with original password after failed recovery status = %d, want 200", loginResp.StatusCode)
	}
	loginResp.Body.Close()
}

func TestAcceptance_RecoveryRedeem_UnknownLoginRejected(t *testing.T) {
	srv, _ := newTestServer(t)
	doJSON(t, http.MethodPost, srv.URL+"/v1/auth/bootstrap", map[string]string{"X-Bootstrap-Token": testBootstrapToken}, validBootstrap("alice")).Body.Close()

	resp := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/recovery/redeem", nil, map[string]any{
		"login":             "nobody",
		"verifier":          "anything",
		"new_password":      "whatever",
		"kdf_salt":          b64(16),
		"kdf_params":        kdfParams(),
		"wrapped_vault_key": b64(48),
		"wrap_nonce":        b64(24),
		"device":            map[string]string{"name": "D", "platform": "android"},
	})
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("recovery redeem for unknown login status = %d, want 401", resp.StatusCode)
	}
	resp.Body.Close()
}
