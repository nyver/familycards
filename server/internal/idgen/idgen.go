// Package idgen centralizes identifier and timestamp generation so the rest
// of the server does not depend directly on uuid/time formatting choices.
package idgen

import (
	"time"

	"github.com/google/uuid"
)

// NewID returns a new random UUID (v4) string, used for server-assigned
// identifiers (vaults, users, devices).
func NewID() string {
	return uuid.NewString()
}

// NowMillis returns the current time as Unix milliseconds.
func NowMillis() int64 {
	return time.Now().UnixMilli()
}

// NowUnix returns the current time as Unix seconds.
func NowUnix() int64 {
	return time.Now().Unix()
}
