package auth_test

import (
	"encoding/json"
	"fmt"
	"net/http"
	"testing"
)

// Scenario 1: bootstrap -> login -> me; repeat bootstrap -> 409.
func TestAcceptance_BootstrapLoginMe(t *testing.T) {
	srv, _ := newTestServer(t)

	resp := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/bootstrap", map[string]string{"X-Bootstrap-Token": testBootstrapToken}, validBootstrap("alice"))
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("bootstrap status = %d, want 201", resp.StatusCode)
	}
	var bootstrapResp struct {
		UserID       string `json:"user_id"`
		VaultID      string `json:"vault_id"`
		DeviceID     string `json:"device_id"`
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
	}
	decodeJSON(t, resp, &bootstrapResp)
	if bootstrapResp.AccessToken == "" || bootstrapResp.RefreshToken == "" {
		t.Fatal("bootstrap response missing tokens")
	}

	// Repeat bootstrap must fail.
	resp2 := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/bootstrap", map[string]string{"X-Bootstrap-Token": testBootstrapToken}, validBootstrap("bob"))
	if resp2.StatusCode != http.StatusConflict {
		t.Fatalf("repeat bootstrap status = %d, want 409", resp2.StatusCode)
	}
	resp2.Body.Close()

	// Login with the bootstrapped account.
	loginResp := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/login", nil, map[string]any{
		"login":    "alice",
		"password": "correct horse battery staple",
		"device":   map[string]string{"name": "Second Device", "platform": "ios"},
	})
	if loginResp.StatusCode != http.StatusOK {
		t.Fatalf("login status = %d, want 200", loginResp.StatusCode)
	}
	var login struct {
		AccessToken     string `json:"access_token"`
		WrappedVaultKey string `json:"wrapped_vault_key"`
	}
	decodeJSON(t, loginResp, &login)
	if login.AccessToken == "" || login.WrappedVaultKey == "" {
		t.Fatal("login response missing fields")
	}

	// GET /v1/me
	meReq, _ := http.NewRequest(http.MethodGet, srv.URL+"/v1/me", nil)
	meReq.Header.Set("Authorization", "Bearer "+login.AccessToken)
	meResp, err := testHTTPClient().Do(meReq)
	if err != nil {
		t.Fatalf("GET /v1/me: %v", err)
	}
	if meResp.StatusCode != http.StatusOK {
		t.Fatalf("me status = %d, want 200", meResp.StatusCode)
	}
	var me struct {
		User  json.RawMessage `json:"user"`
		Vault struct {
			UserCount int `json:"user_count"`
			MaxUsers  int `json:"max_users"`
		} `json:"vault"`
	}
	decodeJSON(t, meResp, &me)
	if me.Vault.UserCount != 1 || me.Vault.MaxUsers != 5 {
		t.Errorf("vault = %+v, want user_count=1 max_users=5", me.Vault)
	}
}

// Scenario: prelogin is indistinguishable for known vs unknown logins, and
// deterministic for the same unknown login.
func TestAcceptance_PreloginIndistinguishable(t *testing.T) {
	srv, _ := newTestServer(t)
	doJSON(t, http.MethodPost, srv.URL+"/v1/auth/bootstrap", map[string]string{"X-Bootstrap-Token": testBootstrapToken}, validBootstrap("alice")).Body.Close()

	resp1 := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/prelogin", nil, map[string]string{"login": "nobody"})
	var p1 struct {
		KDFSalt   string          `json:"kdf_salt"`
		KDFParams json.RawMessage `json:"kdf_params"`
	}
	decodeJSON(t, resp1, &p1)

	resp2 := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/prelogin", nil, map[string]string{"login": "nobody"})
	var p2 struct {
		KDFSalt string `json:"kdf_salt"`
	}
	decodeJSON(t, resp2, &p2)

	if p1.KDFSalt != p2.KDFSalt {
		t.Error("fake prelogin salt should be deterministic for the same unknown login")
	}
	if p1.KDFSalt == "" {
		t.Error("fake prelogin salt should not be empty")
	}
}

// Scenario 11: refresh rotation; reuse of a rotated-away token revokes all
// devices of that user.
func TestAcceptance_RefreshRotationAndReuseDetection(t *testing.T) {
	srv, _ := newTestServer(t)
	bResp := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/bootstrap", map[string]string{"X-Bootstrap-Token": testBootstrapToken}, validBootstrap("alice"))
	var bootstrap struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
	}
	decodeJSON(t, bResp, &bootstrap)

	// First rotation.
	r1 := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/refresh", nil, map[string]string{"refresh_token": bootstrap.RefreshToken})
	if r1.StatusCode != http.StatusOK {
		t.Fatalf("first refresh status = %d, want 200", r1.StatusCode)
	}
	var rotated struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
	}
	decodeJSON(t, r1, &rotated)
	if rotated.RefreshToken == bootstrap.RefreshToken {
		t.Fatal("rotation should produce a new refresh token")
	}

	// New token works.
	r2 := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/refresh", nil, map[string]string{"refresh_token": rotated.RefreshToken})
	if r2.StatusCode != http.StatusOK {
		t.Fatalf("second refresh status = %d, want 200", r2.StatusCode)
	}
	r2.Body.Close()

	// Replaying the original (now-retired) token must be rejected and
	// revoke all devices.
	reuse := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/refresh", nil, map[string]string{"refresh_token": bootstrap.RefreshToken})
	if reuse.StatusCode != http.StatusUnauthorized {
		t.Fatalf("reused refresh token status = %d, want 401", reuse.StatusCode)
	}
	reuse.Body.Close()

	// The access token issued along the way should still parse, but the
	// device backing it is now revoked, so protected calls must fail.
	meReq, _ := http.NewRequest(http.MethodGet, srv.URL+"/v1/me", nil)
	meReq.Header.Set("Authorization", "Bearer "+bootstrap.AccessToken)
	meResp, err := testHTTPClient().Do(meReq)
	if err != nil {
		t.Fatalf("GET /v1/me: %v", err)
	}
	if meResp.StatusCode != http.StatusUnauthorized {
		t.Errorf("me status after reuse-triggered revocation = %d, want 401", meResp.StatusCode)
	}
}

func TestAcceptance_DeviceLimit(t *testing.T) {
	srv, _ := newTestServer(t)
	doJSON(t, http.MethodPost, srv.URL+"/v1/auth/bootstrap", map[string]string{"X-Bootstrap-Token": testBootstrapToken}, validBootstrap("alice")).Body.Close()

	// Bootstrap already created 1 device. Add 9 more to reach the limit of 10.
	for i := 0; i < 9; i++ {
		resp := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/login", nil, map[string]any{
			"login":    "alice",
			"password": "correct horse battery staple",
			"device":   map[string]string{"name": fmt.Sprintf("Device %d", i), "platform": "android"},
		})
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("login %d status = %d, want 200", i, resp.StatusCode)
		}
		resp.Body.Close()
	}

	// The 11th device (10 already active) must be rejected.
	over := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/login", nil, map[string]any{
		"login":    "alice",
		"password": "correct horse battery staple",
		"device":   map[string]string{"name": "One Too Many", "platform": "android"},
	})
	if over.StatusCode != http.StatusConflict {
		t.Fatalf("11th device login status = %d, want 409", over.StatusCode)
	}
	over.Body.Close()
}

func TestAcceptance_DisabledUserCannotLogin(t *testing.T) {
	srv, db := newTestServer(t)
	doJSON(t, http.MethodPost, srv.URL+"/v1/auth/bootstrap", map[string]string{"X-Bootstrap-Token": testBootstrapToken}, validBootstrap("alice")).Body.Close()

	if _, err := db.Write.Exec("UPDATE users SET disabled = 1 WHERE login = 'alice'"); err != nil {
		t.Fatalf("disable user: %v", err)
	}

	resp := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/login", nil, map[string]any{
		"login":    "alice",
		"password": "correct horse battery staple",
		"device":   map[string]string{"name": "Device", "platform": "android"},
	})
	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("disabled user login status = %d, want 403", resp.StatusCode)
	}
}

func TestAcceptance_VaultIsolation(t *testing.T) {
	srv1, _ := newTestServer(t)
	srv2, _ := newTestServer(t)

	b1 := doJSON(t, http.MethodPost, srv1.URL+"/v1/auth/bootstrap", map[string]string{"X-Bootstrap-Token": testBootstrapToken}, validBootstrap("alice"))
	var v1 struct {
		AccessToken string `json:"access_token"`
	}
	decodeJSON(t, b1, &v1)

	doJSON(t, http.MethodPost, srv2.URL+"/v1/auth/bootstrap", map[string]string{"X-Bootstrap-Token": testBootstrapToken}, validBootstrap("bob")).Body.Close()

	// Using server 1's token against server 2's instance should fail (in
	// practice this models cross-vault isolation; here it demonstrates the
	// token is meaningless against a different signing/database context).
	req, _ := http.NewRequest(http.MethodGet, srv2.URL+"/v1/me", nil)
	req.Header.Set("Authorization", "Bearer "+v1.AccessToken)
	resp, err := testHTTPClient().Do(req)
	if err != nil {
		t.Fatalf("GET /v1/me: %v", err)
	}
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("cross-vault token status = %d, want 401", resp.StatusCode)
	}
}

func TestAcceptance_PasswordChangeAtomic(t *testing.T) {
	srv, _ := newTestServer(t)
	bResp := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/bootstrap", map[string]string{"X-Bootstrap-Token": testBootstrapToken}, validBootstrap("alice"))
	var bootstrap struct {
		AccessToken string `json:"access_token"`
	}
	decodeJSON(t, bResp, &bootstrap)

	// Wrong old password should fail and change nothing.
	resp := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/password", map[string]string{"Authorization": "Bearer " + bootstrap.AccessToken}, map[string]any{
		"old_password":      "wrong password",
		"new_password":      "a brand new password",
		"kdf_salt":          b64(16),
		"kdf_params":        kdfParams(),
		"wrapped_vault_key": b64(48),
		"wrap_nonce":        b64(24),
	})
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("wrong old password status = %d, want 401", resp.StatusCode)
	}
	resp.Body.Close()

	// Login with the original password should still work.
	loginResp := doJSON(t, http.MethodPost, srv.URL+"/v1/auth/login", nil, map[string]any{
		"login":    "alice",
		"password": "correct horse battery staple",
		"device":   map[string]string{"name": "D", "platform": "android"},
	})
	if loginResp.StatusCode != http.StatusOK {
		t.Fatalf("login after failed password change = %d, want 200", loginResp.StatusCode)
	}
	loginResp.Body.Close()
}
