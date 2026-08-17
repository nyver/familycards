// Package ratelimit implements an in-memory per-IP token bucket rate
// limiter. State lives only in process memory - acceptable for the target
// single-process, home-server deployment - and is swept periodically so
// long-idle IPs do not accumulate forever.
package ratelimit

import (
	"sync"
	"time"
)

// bucket tracks remaining tokens and the last refill time for one IP.
type bucket struct {
	tokens     float64
	lastRefill time.Time
	lastSeen   time.Time
}

// Limiter is a token bucket rate limiter keyed by an arbitrary string (an
// IP address in practice). Safe for concurrent use.
type Limiter struct {
	mu         sync.Mutex
	buckets    map[string]*bucket
	ratePerMin float64
	burst      float64
	idleExpiry time.Duration
}

// New creates a Limiter allowing ratePerMinute requests per minute per key,
// with a burst capacity equal to ratePerMinute (i.e. a full minute's budget
// can be spent immediately). Keys idle for longer than idleExpiry are
// forgotten on the next Sweep.
func New(ratePerMinute int, idleExpiry time.Duration) *Limiter {
	return &Limiter{
		buckets:    make(map[string]*bucket),
		ratePerMin: float64(ratePerMinute),
		burst:      float64(ratePerMinute),
		idleExpiry: idleExpiry,
	}
}

// Allow reports whether a request for key is permitted right now, consuming
// one token if so. When it returns false, retryAfter is the minimum time
// the caller should wait before trying again.
func (l *Limiter) Allow(key string) (allowed bool, retryAfter time.Duration) {
	l.mu.Lock()
	defer l.mu.Unlock()

	now := time.Now()
	b, ok := l.buckets[key]
	if !ok {
		b = &bucket{tokens: l.burst, lastRefill: now}
		l.buckets[key] = b
	}
	b.lastSeen = now

	elapsed := now.Sub(b.lastRefill).Minutes()
	b.tokens = min(l.burst, b.tokens+elapsed*l.ratePerMin)
	b.lastRefill = now

	if b.tokens >= 1 {
		b.tokens--
		return true, 0
	}

	deficit := 1 - b.tokens
	wait := time.Duration(deficit / l.ratePerMin * float64(time.Minute))
	return false, wait
}

// Sweep removes buckets that have been idle longer than idleExpiry,
// bounding memory growth. Intended to run periodically from a background
// goroutine.
func (l *Limiter) Sweep() {
	l.mu.Lock()
	defer l.mu.Unlock()

	cutoff := time.Now().Add(-l.idleExpiry)
	for key, b := range l.buckets {
		if b.lastSeen.Before(cutoff) {
			delete(l.buckets, key)
		}
	}
}

// Len reports the number of tracked keys, mainly for tests.
func (l *Limiter) Len() int {
	l.mu.Lock()
	defer l.mu.Unlock()
	return len(l.buckets)
}

func min(a, b float64) float64 {
	if a < b {
		return a
	}
	return b
}
