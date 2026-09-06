package config

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

const testSecret = "0123456789abcdef0123456789abcdef"

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

func TestLoad_TLSModeDefaultsToOff(t *testing.T) {
	withEnv(t, map[string]string{"WALLET_JWT_SECRET": testSecret}, func() {
		cfg, err := Load()
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if cfg.TLSMode != TLSModeOff {
			t.Errorf("TLSMode = %q, want %q", cfg.TLSMode, TLSModeOff)
		}
		if len(cfg.TLSDomains) != 0 {
			t.Errorf("TLSDomains = %v, want empty", cfg.TLSDomains)
		}
	})
}

func TestLoad_TLSCacheDirDefault(t *testing.T) {
	withEnv(t, map[string]string{
		"WALLET_JWT_SECRET": testSecret,
		"WALLET_DB_PATH":    filepath.Join("some", "dir", "wallet.db"),
	}, func() {
		cfg, err := Load()
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		want := filepath.Join("some", "dir", "certs")
		if cfg.TLSCacheDir != want {
			t.Errorf("TLSCacheDir = %q, want %q", cfg.TLSCacheDir, want)
		}
	})
}

func TestLoad_TLSDomainsParsing(t *testing.T) {
	withEnv(t, map[string]string{
		"WALLET_JWT_SECRET":  testSecret,
		"WALLET_TLS_MODE":    "acme",
		"WALLET_TLS_DOMAINS": " example.com ,, second.example.com ,   ",
	}, func() {
		cfg, err := Load()
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		want := []string{"example.com", "second.example.com"}
		if len(cfg.TLSDomains) != len(want) {
			t.Fatalf("TLSDomains = %v, want %v", cfg.TLSDomains, want)
		}
		for i := range want {
			if cfg.TLSDomains[i] != want[i] {
				t.Errorf("TLSDomains[%d] = %q, want %q", i, cfg.TLSDomains[i], want[i])
			}
		}
	})
}

func TestLoad_SelfSignedDefaultNames_WildcardAddr(t *testing.T) {
	withEnv(t, map[string]string{
		"WALLET_JWT_SECRET": testSecret,
		"WALLET_TLS_MODE":   "selfsigned",
		"WALLET_ADDR":       ":8443",
	}, func() {
		cfg, err := Load()
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		want := []string{"localhost", "127.0.0.1"}
		if len(cfg.TLSDomains) != len(want) {
			t.Fatalf("TLSDomains = %v, want %v", cfg.TLSDomains, want)
		}
	})
}

func TestLoad_SelfSignedDefaultNames_HostAddr(t *testing.T) {
	withEnv(t, map[string]string{
		"WALLET_JWT_SECRET": testSecret,
		"WALLET_TLS_MODE":   "selfsigned",
		"WALLET_ADDR":       "vps.example.com:8443",
	}, func() {
		cfg, err := Load()
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		want := []string{"localhost", "127.0.0.1", "vps.example.com"}
		if len(cfg.TLSDomains) != len(want) {
			t.Fatalf("TLSDomains = %v, want %v", cfg.TLSDomains, want)
		}
		for i := range want {
			if cfg.TLSDomains[i] != want[i] {
				t.Errorf("TLSDomains[%d] = %q, want %q", i, cfg.TLSDomains[i], want[i])
			}
		}
	})
}

func TestLoad_SelfSignedExplicitDomainsNotOverridden(t *testing.T) {
	withEnv(t, map[string]string{
		"WALLET_JWT_SECRET":  testSecret,
		"WALLET_TLS_MODE":    "selfsigned",
		"WALLET_TLS_DOMAINS": "custom.example.com",
	}, func() {
		cfg, err := Load()
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if len(cfg.TLSDomains) != 1 || cfg.TLSDomains[0] != "custom.example.com" {
			t.Errorf("TLSDomains = %v, want [custom.example.com]", cfg.TLSDomains)
		}
	})
}

func TestLoad_UnknownTLSMode(t *testing.T) {
	withEnv(t, map[string]string{
		"WALLET_JWT_SECRET": testSecret,
		"WALLET_TLS_MODE":   "bogus",
	}, func() {
		_, err := Load()
		if err == nil {
			t.Fatal("expected error for unknown WALLET_TLS_MODE")
		}
		if !strings.Contains(err.Error(), "WALLET_TLS_MODE") {
			t.Errorf("error = %q, want it to name WALLET_TLS_MODE", err.Error())
		}
	})
}

func TestLoad_ACMEEmptyDomains(t *testing.T) {
	withEnv(t, map[string]string{
		"WALLET_JWT_SECRET": testSecret,
		"WALLET_TLS_MODE":   "acme",
	}, func() {
		_, err := Load()
		if err == nil {
			t.Fatal("expected error for acme mode with empty WALLET_TLS_DOMAINS")
		}
		if !strings.Contains(err.Error(), "WALLET_TLS_DOMAINS") {
			t.Errorf("error = %q, want it to name WALLET_TLS_DOMAINS", err.Error())
		}
	})
}

func TestLoad_FileModeMissingCertFile(t *testing.T) {
	withEnv(t, map[string]string{
		"WALLET_JWT_SECRET":   testSecret,
		"WALLET_TLS_MODE":     "file",
		"WALLET_TLS_KEY_FILE": "key.pem",
	}, func() {
		_, err := Load()
		if err == nil {
			t.Fatal("expected error for file mode missing WALLET_TLS_CERT_FILE")
		}
		if !strings.Contains(err.Error(), "WALLET_TLS_CERT_FILE") {
			t.Errorf("error = %q, want it to name WALLET_TLS_CERT_FILE", err.Error())
		}
	})
}

func TestLoad_FileModeMissingKeyFile(t *testing.T) {
	withEnv(t, map[string]string{
		"WALLET_JWT_SECRET":    testSecret,
		"WALLET_TLS_MODE":      "file",
		"WALLET_TLS_CERT_FILE": "cert.pem",
	}, func() {
		_, err := Load()
		if err == nil {
			t.Fatal("expected error for file mode missing WALLET_TLS_KEY_FILE")
		}
		if !strings.Contains(err.Error(), "WALLET_TLS_KEY_FILE") {
			t.Errorf("error = %q, want it to name WALLET_TLS_KEY_FILE", err.Error())
		}
	})
}

func TestLoad_FileModeUnloadablePair(t *testing.T) {
	dir := t.TempDir()
	certPath := filepath.Join(dir, "cert.pem")
	keyPath := filepath.Join(dir, "key.pem")
	writeFile(t, certPath, "not a certificate")
	writeFile(t, keyPath, "not a key")

	withEnv(t, map[string]string{
		"WALLET_JWT_SECRET":    testSecret,
		"WALLET_TLS_MODE":      "file",
		"WALLET_TLS_CERT_FILE": certPath,
		"WALLET_TLS_KEY_FILE":  keyPath,
	}, func() {
		_, err := Load()
		if err == nil {
			t.Fatal("expected error for unloadable cert/key pair")
		}
	})
}

func TestLoad_TLSModeWithAllowInsecureConflict(t *testing.T) {
	for _, mode := range []string{"acme", "file", "selfsigned"} {
		mode := mode
		t.Run(mode, func(t *testing.T) {
			env := map[string]string{
				"WALLET_JWT_SECRET":     testSecret,
				"WALLET_TLS_MODE":       mode,
				"WALLET_ALLOW_INSECURE": "true",
			}
			if mode == "acme" {
				env["WALLET_TLS_DOMAINS"] = "example.com"
			}
			if mode == "file" {
				dir := t.TempDir()
				env["WALLET_TLS_CERT_FILE"] = filepath.Join(dir, "cert.pem")
				env["WALLET_TLS_KEY_FILE"] = filepath.Join(dir, "key.pem")
			}
			withEnv(t, env, func() {
				_, err := Load()
				if err == nil {
					t.Fatalf("expected error for WALLET_TLS_MODE=%s with WALLET_ALLOW_INSECURE=true", mode)
				}
				if !strings.Contains(err.Error(), "WALLET_ALLOW_INSECURE") {
					t.Errorf("error = %q, want it to mention WALLET_ALLOW_INSECURE", err.Error())
				}
			})
		})
	}
}

func TestLoad_ErrorsNeverContainSecretValues(t *testing.T) {
	const secretMarker = "0123456789abcdef0123456789abcdef"
	const bootstrapMarker = "bootstrap-secret-marker"
	const adminMarker = "admin-secret-marker"

	cases := []map[string]string{
		{"WALLET_JWT_SECRET": ""},
		{"WALLET_JWT_SECRET": "too-short"},
		{"WALLET_JWT_SECRET": secretMarker, "WALLET_TOMBSTONE_DAYS": "not-a-number"},
		{"WALLET_JWT_SECRET": secretMarker, "WALLET_ALLOW_INSECURE": "maybe"},
		{"WALLET_JWT_SECRET": secretMarker, "WALLET_TLS_MODE": "bogus"},
		{"WALLET_JWT_SECRET": secretMarker, "WALLET_TLS_MODE": "acme"},
		{"WALLET_JWT_SECRET": secretMarker, "WALLET_TLS_MODE": "file"},
		{"WALLET_JWT_SECRET": secretMarker, "WALLET_TLS_MODE": "acme", "WALLET_ALLOW_INSECURE": "true", "WALLET_TLS_DOMAINS": "example.com"},
	}

	for i, kv := range cases {
		kv := kv
		kv["WALLET_BOOTSTRAP_TOKEN"] = bootstrapMarker
		kv["WALLET_ADMIN_TOKEN"] = adminMarker
		t.Run(strconv.Itoa(i), func(t *testing.T) {
			withEnv(t, kv, func() {
				_, err := Load()
				if err == nil {
					return
				}
				msg := err.Error()
				if strings.Contains(msg, secretMarker) {
					t.Errorf("error message leaks WALLET_JWT_SECRET value: %q", msg)
				}
				if strings.Contains(msg, bootstrapMarker) {
					t.Errorf("error message leaks WALLET_BOOTSTRAP_TOKEN value: %q", msg)
				}
				if strings.Contains(msg, adminMarker) {
					t.Errorf("error message leaks WALLET_ADMIN_TOKEN value: %q", msg)
				}
			})
		})
	}
}

func writeFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
}
