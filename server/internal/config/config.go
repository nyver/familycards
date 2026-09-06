// Package config loads server configuration from environment variables.
package config

import (
	"crypto/tls"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

const minJWTSecretBytes = 32

// TLSMode selects how the server terminates TLS.
type TLSMode string

const (
	// TLSModeOff means TLS is terminated by an external reverse proxy (e.g.
	// Caddy); the server itself only speaks plain HTTP and trusts
	// X-Forwarded-Proto/X-Forwarded-For.
	TLSModeOff TLSMode = "off"
	// TLSModeACME means the server terminates TLS itself, obtaining and
	// renewing certificates automatically via ACME (Let's Encrypt).
	TLSModeACME TLSMode = "acme"
	// TLSModeFile means the server terminates TLS itself using a
	// certificate/key pair loaded from disk.
	TLSModeFile TLSMode = "file"
	// TLSModeSelfSigned means the server terminates TLS itself using a
	// self-signed certificate it issues and persists on its own.
	TLSModeSelfSigned TLSMode = "selfsigned"
)

// Config holds all server configuration read from the environment.
type Config struct {
	Addr           string
	DBPath         string
	BlobDir        string
	JWTSecret      []byte
	BootstrapToken string
	AdminToken     string
	LogLevel       string
	AllowInsecure  bool
	TombstoneDays  int

	// TLS configuration. TLSMode defaults to TLSModeOff, reproducing the
	// pre-existing behind-a-proxy behavior exactly.
	TLSMode      TLSMode
	TLSDomains   []string
	TLSCertFile  string
	TLSKeyFile   string
	TLSCacheDir  string
	TLSACMEEmail string
	HTTPAddr     string
}

// Load reads configuration from environment variables and validates it.
// It returns an error naming the offending variable; it never includes
// secret values in the returned error.
func Load() (Config, error) {
	cfg := Config{
		Addr:           getEnv("WALLET_ADDR", ":8443"),
		DBPath:         getEnv("WALLET_DB_PATH", "data/wallet.db"),
		BlobDir:        getEnv("WALLET_BLOB_DIR", "data/blobs"),
		BootstrapToken: os.Getenv("WALLET_BOOTSTRAP_TOKEN"),
		AdminToken:     os.Getenv("WALLET_ADMIN_TOKEN"),
		LogLevel:       getEnv("WALLET_LOG_LEVEL", "info"),
		TombstoneDays:  90,
	}

	secret := os.Getenv("WALLET_JWT_SECRET")
	if secret == "" {
		return Config{}, fmt.Errorf("config: WALLET_JWT_SECRET is required")
	}
	if len(secret) < minJWTSecretBytes {
		return Config{}, fmt.Errorf("config: WALLET_JWT_SECRET must be at least %d bytes", minJWTSecretBytes)
	}
	cfg.JWTSecret = []byte(secret)

	if raw := os.Getenv("WALLET_ALLOW_INSECURE"); raw != "" {
		v, err := strconv.ParseBool(raw)
		if err != nil {
			return Config{}, fmt.Errorf("config: WALLET_ALLOW_INSECURE must be a boolean")
		}
		cfg.AllowInsecure = v
	}

	if raw := os.Getenv("WALLET_TOMBSTONE_DAYS"); raw != "" {
		v, err := strconv.Atoi(raw)
		if err != nil || v <= 0 {
			return Config{}, fmt.Errorf("config: WALLET_TOMBSTONE_DAYS must be a positive integer")
		}
		cfg.TombstoneDays = v
	}

	if err := loadTLS(&cfg); err != nil {
		return Config{}, err
	}

	return cfg, nil
}

// loadTLS populates and validates the TLS-related fields of cfg. It is
// split out of Load for readability; cfg.Addr, cfg.DBPath and
// cfg.AllowInsecure must already be set.
func loadTLS(cfg *Config) error {
	mode := TLSMode(getEnv("WALLET_TLS_MODE", string(TLSModeOff)))
	switch mode {
	case TLSModeOff, TLSModeACME, TLSModeFile, TLSModeSelfSigned:
	default:
		return fmt.Errorf("config: WALLET_TLS_MODE has an unknown value")
	}
	cfg.TLSMode = mode

	cfg.TLSDomains = parseDomainList(os.Getenv("WALLET_TLS_DOMAINS"))
	cfg.TLSCertFile = os.Getenv("WALLET_TLS_CERT_FILE")
	cfg.TLSKeyFile = os.Getenv("WALLET_TLS_KEY_FILE")
	cfg.TLSCacheDir = getEnv("WALLET_TLS_CACHE_DIR", filepath.Join(filepath.Dir(cfg.DBPath), "certs"))
	cfg.TLSACMEEmail = os.Getenv("WALLET_TLS_ACME_EMAIL")
	cfg.HTTPAddr = os.Getenv("WALLET_HTTP_ADDR")

	if mode != TLSModeOff && cfg.AllowInsecure {
		return fmt.Errorf("config: WALLET_TLS_MODE=%s cannot be combined with WALLET_ALLOW_INSECURE=true", mode)
	}

	switch mode {
	case TLSModeACME:
		if len(cfg.TLSDomains) == 0 {
			return fmt.Errorf("config: WALLET_TLS_DOMAINS is required when WALLET_TLS_MODE=acme")
		}
	case TLSModeFile:
		if cfg.TLSCertFile == "" {
			return fmt.Errorf("config: WALLET_TLS_CERT_FILE is required when WALLET_TLS_MODE=file")
		}
		if cfg.TLSKeyFile == "" {
			return fmt.Errorf("config: WALLET_TLS_KEY_FILE is required when WALLET_TLS_MODE=file")
		}
		if _, err := tls.LoadX509KeyPair(cfg.TLSCertFile, cfg.TLSKeyFile); err != nil {
			// err never contains the private key's contents - only parse
			// errors and/or the configured file paths, neither of which
			// is a secret value.
			return fmt.Errorf("config: WALLET_TLS_CERT_FILE/WALLET_TLS_KEY_FILE do not form a loadable certificate pair: %w", err)
		}
	case TLSModeSelfSigned:
		if len(cfg.TLSDomains) == 0 {
			cfg.TLSDomains = defaultSelfSignedNames(cfg.Addr)
		}
	}

	return nil
}

// defaultSelfSignedNames returns the default SAN names for a self-signed
// certificate when WALLET_TLS_DOMAINS is empty: localhost, 127.0.0.1, and
// the host part of addr when it is non-empty and not a wildcard bind (e.g.
// ":8443" or "0.0.0.0:8443" carry no meaningful host).
func defaultSelfSignedNames(addr string) []string {
	names := []string{"localhost", "127.0.0.1"}
	host, _, err := net.SplitHostPort(addr)
	if err != nil {
		host = addr
	}
	switch host {
	case "", "0.0.0.0", "::", "[::]":
		return names
	}
	return append(names, host)
}

// parseDomainList splits a comma-separated list, trims whitespace around
// each entry, and drops empty entries.
func parseDomainList(raw string) []string {
	if raw == "" {
		return nil
	}
	var out []string
	for _, part := range strings.Split(raw, ",") {
		trimmed := strings.TrimSpace(part)
		if trimmed != "" {
			out = append(out, trimmed)
		}
	}
	return out
}

func getEnv(key, fallback string) string {
	if v, ok := os.LookupEnv(key); ok && strings.TrimSpace(v) != "" {
		return v
	}
	return fallback
}
