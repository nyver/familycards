package ratelimit

import (
	"net/http"
	"strconv"
)

// Middleware returns HTTP middleware that rate-limits by client IP using
// limiter, writing 429 with a Retry-After header when exceeded. clientIP
// extracts the key to rate-limit on (see httpapi.ClientIP).
func Middleware(limiter *Limiter, clientIP func(*http.Request) string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			allowed, retryAfter := limiter.Allow(clientIP(r))
			if !allowed {
				w.Header().Set("Retry-After", strconv.Itoa(int(retryAfter.Seconds()+1)))
				w.Header().Set("Content-Type", "application/json; charset=utf-8")
				w.WriteHeader(http.StatusTooManyRequests)
				w.Write([]byte(`{"error":"rate_limited","message":"too many requests"}`))
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
