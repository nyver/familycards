package membership_test

import (
	"encoding/json"
	"net/http"
	"strings"
	"sync"
	"testing"
)

type bootstrapResp struct {
	UserID       string `json:"user_id"`
	VaultID      string `json:"vault_id"`
	DeviceID     string `json:"device_id"`
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
}

func bootstrap(t *testing.T, srvURL, login string) bootstrapResp {
	t.Helper()
	resp := doJSON(t, http.MethodPost, srvURL+"/v1/auth/bootstrap", map[string]string{"X-Bootstrap-Token": testBootstrapToken}, validBootstrap(login))
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

// Scenario 2: A creates an invite, B redeems it, B sees the same vault;
// redeeming again -> 410.
func TestAcceptance_InviteAndRedeem(t *testing.T) {
	srv, _ := newTestServer(t)
	a := bootstrap(t, srv.URL, "alice")

	code := "7K4M-9QRT"
	codeHash := sha256Hex(code)

	createResp := doJSON(t, http.MethodPost, srv.URL+"/v1/invites", authHeader(a.AccessToken), map[string]any{
		"code_hash":         codeHash,
		"wrapped_vault_key": b64(48),
		"wrap_nonce":        b64(24),
		"kdf_salt":          b64(16),
		"kdf_params":        kdfParams(),
		"ttl_hours":         24,
	})
	if createResp.StatusCode != http.StatusCreated {
		t.Fatalf("create invite status = %d, want 201", createResp.StatusCode)
	}
	createResp.Body.Close()

	getResp := doJSON(t, http.MethodGet, srv.URL+"/v1/invites/"+codeHash, nil, nil)
	if getResp.StatusCode != http.StatusOK {
		t.Fatalf("get invite status = %d, want 200", getResp.StatusCode)
	}
	getResp.Body.Close()

	redeemResp := doJSON(t, http.MethodPost, srv.URL+"/v1/invites/"+codeHash+"/redeem", nil, map[string]any{
		"login":             "bob",
		"display_name":      "Bob",
		"password":          "another good password",
		"kdf_salt":          b64(16),
		"kdf_params":        kdfParams(),
		"wrapped_vault_key": b64(48),
		"wrap_nonce":        b64(24),
		"device":            map[string]string{"name": "Bob's Phone", "platform": "ios"},
	})
	if redeemResp.StatusCode != http.StatusOK {
		t.Fatalf("redeem status = %d, want 200", redeemResp.StatusCode)
	}
	var b bootstrapResp
	decodeJSON(t, redeemResp, &b)
	if b.VaultID != a.VaultID {
		t.Errorf("redeemed vault_id = %q, want %q (same family vault)", b.VaultID, a.VaultID)
	}

	// Redeeming again must fail.
	redeemAgain := doJSON(t, http.MethodPost, srv.URL+"/v1/invites/"+codeHash+"/redeem", nil, map[string]any{
		"login":             "carol",
		"display_name":      "Carol",
		"password":          "yet another password",
		"kdf_salt":          b64(16),
		"kdf_params":        kdfParams(),
		"wrapped_vault_key": b64(48),
		"wrap_nonce":        b64(24),
		"device":            map[string]string{"name": "Carol's Phone", "platform": "android"},
	})
	if redeemAgain.StatusCode != http.StatusGone {
		t.Errorf("repeat redeem status = %d, want 410", redeemAgain.StatusCode)
	}
	redeemAgain.Body.Close()
}

// Scenario 3: the 6th redeem must fail (max_users = 5).
func TestAcceptance_MemberLimit(t *testing.T) {
	srv, _ := newTestServer(t)
	a := bootstrap(t, srv.URL, "alice")

	// alice is user #1. Add 4 more via invites to reach 5.
	for i := 0; i < 4; i++ {
		redeemViaFreshInvite(t, srv.URL, a.AccessToken, "member"+string(rune('a'+i)))
	}

	// 6th user must be rejected.
	code := "AAAA-1111"
	codeHash := sha256Hex(code)
	createResp := doJSON(t, http.MethodPost, srv.URL+"/v1/invites", authHeader(a.AccessToken), map[string]any{
		"code_hash": codeHash, "wrapped_vault_key": b64(48), "wrap_nonce": b64(24),
		"kdf_salt": b64(16), "kdf_params": kdfParams(), "ttl_hours": 24,
	})
	if createResp.StatusCode != http.StatusConflict {
		t.Fatalf("6th invite create status = %d, want 409 (quota already at max_users via existing members)", createResp.StatusCode)
	}
	createResp.Body.Close()
}

func redeemViaFreshInvite(t *testing.T, srvURL, ownerToken, login string) {
	t.Helper()
	codeHash := sha256Hex(login + "-code")
	createResp := doJSON(t, http.MethodPost, srvURL+"/v1/invites", authHeader(ownerToken), map[string]any{
		"code_hash": codeHash, "wrapped_vault_key": b64(48), "wrap_nonce": b64(24),
		"kdf_salt": b64(16), "kdf_params": kdfParams(), "ttl_hours": 24,
	})
	if createResp.StatusCode != http.StatusCreated {
		t.Fatalf("create invite for %s status = %d, want 201", login, createResp.StatusCode)
	}
	createResp.Body.Close()

	redeemResp := doJSON(t, http.MethodPost, srvURL+"/v1/invites/"+codeHash+"/redeem", nil, map[string]any{
		"login": login, "display_name": login, "password": "a perfectly fine password",
		"kdf_salt": b64(16), "kdf_params": kdfParams(), "wrapped_vault_key": b64(48), "wrap_nonce": b64(24),
		"device": map[string]string{"name": login + "-device", "platform": "android"},
	})
	if redeemResp.StatusCode != http.StatusOK {
		t.Fatalf("redeem for %s status = %d, want 200", login, redeemResp.StatusCode)
	}
	redeemResp.Body.Close()
}

func TestAcceptance_QuotaCountsPendingInvites(t *testing.T) {
	srv, _ := newTestServer(t)
	a := bootstrap(t, srv.URL, "alice")

	// alice (1) + 4 pending invites = 5, at quota. A 5th invite must fail.
	for i := 0; i < 4; i++ {
		codeHash := sha256Hex("pending" + string(rune('a'+i)))
		resp := doJSON(t, http.MethodPost, srv.URL+"/v1/invites", authHeader(a.AccessToken), map[string]any{
			"code_hash": codeHash, "wrapped_vault_key": b64(48), "wrap_nonce": b64(24),
			"kdf_salt": b64(16), "kdf_params": kdfParams(), "ttl_hours": 24,
		})
		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("invite %d status = %d, want 201", i, resp.StatusCode)
		}
		resp.Body.Close()
	}

	resp := doJSON(t, http.MethodPost, srv.URL+"/v1/invites", authHeader(a.AccessToken), map[string]any{
		"code_hash": sha256Hex("one-too-many"), "wrapped_vault_key": b64(48), "wrap_nonce": b64(24),
		"kdf_salt": b64(16), "kdf_params": kdfParams(), "ttl_hours": 24,
	})
	if resp.StatusCode != http.StatusConflict {
		t.Errorf("5th pending invite status = %d, want 409 (quota counts pending invites)", resp.StatusCode)
	}
	resp.Body.Close()
}

func TestAcceptance_ConcurrentRedeemRace(t *testing.T) {
	srv, _ := newTestServer(t)
	a := bootstrap(t, srv.URL, "alice")

	codeHash := sha256Hex("race-code")
	createResp := doJSON(t, http.MethodPost, srv.URL+"/v1/invites", authHeader(a.AccessToken), map[string]any{
		"code_hash": codeHash, "wrapped_vault_key": b64(48), "wrap_nonce": b64(24),
		"kdf_salt": b64(16), "kdf_params": kdfParams(), "ttl_hours": 24,
	})
	if createResp.StatusCode != http.StatusCreated {
		t.Fatalf("create invite status = %d, want 201", createResp.StatusCode)
	}
	createResp.Body.Close()

	var wg sync.WaitGroup
	statuses := make([]int, 2)
	logins := []string{"racer1", "racer2"}
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			resp := doJSON(t, http.MethodPost, srv.URL+"/v1/invites/"+codeHash+"/redeem", nil, map[string]any{
				"login": logins[i], "display_name": logins[i], "password": "a perfectly fine password",
				"kdf_salt": b64(16), "kdf_params": kdfParams(), "wrapped_vault_key": b64(48), "wrap_nonce": b64(24),
				"device": map[string]string{"name": "d", "platform": "android"},
			})
			statuses[i] = resp.StatusCode
			resp.Body.Close()
		}(i)
	}
	wg.Wait()

	successCount := 0
	for _, s := range statuses {
		if s == http.StatusOK {
			successCount++
		}
	}
	if successCount != 1 {
		t.Errorf("concurrent redeem successes = %d, want exactly 1", successCount)
	}
}

func TestAcceptance_RemoveLastMemberFails(t *testing.T) {
	srv, _ := newTestServer(t)
	a := bootstrap(t, srv.URL, "alice")

	resp := doJSON(t, http.MethodDelete, srv.URL+"/v1/members/"+a.UserID, authHeader(a.AccessToken), nil)
	if resp.StatusCode != http.StatusConflict {
		t.Errorf("removing the last member status = %d, want 409", resp.StatusCode)
	}
	resp.Body.Close()
}

func TestAcceptance_MembersResponseHasNoSecrets(t *testing.T) {
	srv, _ := newTestServer(t)
	a := bootstrap(t, srv.URL, "alice")

	resp := doJSON(t, http.MethodGet, srv.URL+"/v1/members", authHeader(a.AccessToken), nil)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("list members status = %d, want 200", resp.StatusCode)
	}
	var raw json.RawMessage
	decodeJSON(t, resp, &raw)

	forbidden := []string{"password_hash", "wrapped_vault_key", "wrap_nonce", "refresh_hash", "kdf_salt"}
	text := string(raw)
	for _, field := range forbidden {
		if strings.Contains(text, field) {
			t.Errorf("members response leaks field %q: %s", field, text)
		}
	}
}
