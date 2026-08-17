// Package logging configures structured JSON logging and provides helpers
// that keep sensitive values (secrets, ciphertext, blob ids) out of logs.
package logging

import (
	"log/slog"
	"os"
	"strings"
)

// New builds a JSON slog.Logger at the given level name ("debug", "info",
// "warn", "error"). Unknown level names fall back to "info".
func New(levelName string) *slog.Logger {
	handler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: parseLevel(levelName),
	})
	return slog.New(handler)
}

func parseLevel(name string) slog.Level {
	switch strings.ToLower(strings.TrimSpace(name)) {
	case "debug":
		return slog.LevelDebug
	case "warn", "warning":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}

// BlobIDPrefix returns at most the first 8 characters of a blob id, safe to
// place in logs. Full blob ids must never be logged.
func BlobIDPrefix(blobID string) string {
	if len(blobID) <= 8 {
		return blobID
	}
	return blobID[:8]
}
