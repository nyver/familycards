package config

import "testing"

func withEnv(t *testing.T, kv map[string]string, fn func()) {
	t.Helper()
	for k, v := range kv {
		t.Setenv(k, v)
	}
	fn()
}

func TestLoad_MissingSecret(t *testing.T) {
	withEnv(t, map[string]string{"WALLET_JWT_SECRET": ""}, func() {
		if _, err := Load(); err == nil {
			t.Fatal("expected error for missing WALLET_JWT_SECRET")
		}
	})
}

func TestLoad_ShortSecret(t *testing.T) {
	withEnv(t, map[string]string{"WALLET_JWT_SECRET": "too-short"}, func() {
		if _, err := Load(); err == nil {
			t.Fatal("expected error for short WALLET_JWT_SECRET")
		}
	})
}

func TestLoad_Defaults(t *testing.T) {
	secret := "0123456789abcdef0123456789abcdef"
	withEnv(t, map[string]string{"WALLET_JWT_SECRET": secret}, func() {
		cfg, err := Load()
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if cfg.Addr != ":8443" {
			t.Errorf("Addr = %q, want :8443", cfg.Addr)
		}
		if cfg.TombstoneDays != 90 {
			t.Errorf("TombstoneDays = %d, want 90", cfg.TombstoneDays)
		}
		if cfg.AllowInsecure {
			t.Error("AllowInsecure should default to false")
		}
	})
}

func TestLoad_InvalidTombstoneDays(t *testing.T) {
	secret := "0123456789abcdef0123456789abcdef"
	withEnv(t, map[string]string{
		"WALLET_JWT_SECRET":     secret,
		"WALLET_TOMBSTONE_DAYS": "not-a-number",
	}, func() {
		if _, err := Load(); err == nil {
			t.Fatal("expected error for invalid WALLET_TOMBSTONE_DAYS")
		}
	})
}

func TestLoad_InvalidAllowInsecure(t *testing.T) {
	secret := "0123456789abcdef0123456789abcdef"
	withEnv(t, map[string]string{
		"WALLET_JWT_SECRET":     secret,
		"WALLET_ALLOW_INSECURE": "maybe",
	}, func() {
		if _, err := Load(); err == nil {
			t.Fatal("expected error for invalid WALLET_ALLOW_INSECURE")
		}
	})
}
