package httpapi

import (
	"context"
	"log/slog"
	"net"
	"net/http"
	"strings"
	"time"
)

const (
	maxBodyBytesDefault = 1 << 20 // 1 MiB
	maxBodyBytesBlob    = 8 << 20 // 8 MiB
	blobsPathPrefix     = "/v1/blobs"
)

// Recover catches panics in downstream handlers, logs them, and returns a
// generic 500 instead of crashing the process or leaking a stack trace to
// the client.
func Recover(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				slog.Error("httpapi: panic recovered", "panic", rec, "path", r.URL.Path)
				WriteJSON(w, http.StatusInternalServerError, &APIError{Code: "internal_error", Message: "internal server error"})
			}
		}()
		next.ServeHTTP(w, r)
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (rec *statusRecorder) WriteHeader(status int) {
	rec.status = status
	rec.ResponseWriter.WriteHeader(status)
}

// RequestLogger logs one structured line per request. Client errors (4xx)
// log at info level, not error - only unexpected server-side failures
// (which handlers report via WriteError) are logged as errors, separately,
// at the point they occur.
func RequestLogger(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		slog.Info("http request",
			"method", r.Method,
			"path", r.URL.Path,
			"status", rec.status,
			"duration_ms", time.Since(start).Milliseconds(),
		)
	})
}

// LimitBody wraps the request body in http.MaxBytesReader, using the larger
// blob limit only for POST /v1/blobs.
func LimitBody(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		limit := int64(maxBodyBytesDefault)
		if r.URL.Path == blobsPathPrefix {
			limit = maxBodyBytesBlob
		}
		r.Body = http.MaxBytesReader(w, r.Body, limit)
		next.ServeHTTP(w, r)
	})
}

// EnforceHTTPS rejects requests that did not arrive over HTTPS, as reported
// by a trusted reverse proxy's X-Forwarded-Proto header. When allowInsecure
// is true (local development only) the check is skipped.
func EnforceHTTPS(allowInsecure bool) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		if allowInsecure {
			return next
		}
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.Header.Get("X-Forwarded-Proto") != "https" {
				WriteError(w, ErrBadRequest("HTTPS required"))
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// clientIPKey is used to stash the resolved client IP in the request
// context for downstream rate limiting.
type clientIPKeyType struct{}

var clientIPKey clientIPKeyType

// ResolveClientIP extracts the caller's IP address into the request
// context. When trustProxy is false, X-Forwarded-For is ignored (an
// untrusted proxy header would let a client forge any IP and bypass rate
// limiting entirely) and the immediate TCP peer is used instead.
func ResolveClientIP(trustProxy bool) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ip := remoteAddrIP(r.RemoteAddr)
			if trustProxy {
				if fwd := r.Header.Get("X-Forwarded-For"); fwd != "" {
					ip = firstForwardedIP(fwd)
				}
			}
			ctx := context.WithValue(r.Context(), clientIPKey, ip)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// ClientIP retrieves the IP address resolved by ResolveClientIP.
func ClientIP(r *http.Request) string {
	if v, ok := r.Context().Value(clientIPKey).(string); ok {
		return v
	}
	return remoteAddrIP(r.RemoteAddr)
}

func remoteAddrIP(remoteAddr string) string {
	if host, _, err := net.SplitHostPort(remoteAddr); err == nil {
		return host
	}
	return remoteAddr
}

func firstForwardedIP(header string) string {
	parts := strings.SplitN(header, ",", 2)
	return strings.TrimSpace(parts[0])
}
