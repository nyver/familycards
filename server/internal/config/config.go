// Package config loads server configuration from environment variables.
package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

const minJWTSecretBytes = 32

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

	return cfg, nil
}

func getEnv(key, fallback string) string {
	if v, ok := os.LookupEnv(key); ok && strings.TrimSpace(v) != "" {
		return v
	}
	return fallback
}
