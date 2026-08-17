package ratelimit

import (
	"testing"
	"time"
)

func TestAllow_WithinBurst(t *testing.T) {
	l := New(10, time.Hour)
	for i := 0; i < 10; i++ {
		allowed, _ := l.Allow("1.2.3.4")
		if !allowed {
			t.Fatalf("request %d should be allowed within burst", i+1)
		}
	}
	allowed, retryAfter := l.Allow("1.2.3.4")
	if allowed {
		t.Fatal("11th request should be denied")
	}
	if retryAfter <= 0 {
		t.Error("expected positive retryAfter when denied")
	}
}

func TestAllow_IndependentKeys(t *testing.T) {
	l := New(1, time.Hour)
	if allowed, _ := l.Allow("a"); !allowed {
		t.Fatal("first request for key a should be allowed")
	}
	if allowed, _ := l.Allow("a"); allowed {
		t.Fatal("second immediate request for key a should be denied")
	}
	if allowed, _ := l.Allow("b"); !allowed {
		t.Fatal("key b should be unaffected by key a's exhausted bucket")
	}
}

func TestSweep_RemovesIdleKeys(t *testing.T) {
	l := New(10, 10*time.Millisecond)
	l.Allow("stale")
	time.Sleep(20 * time.Millisecond)
	l.Allow("fresh")

	l.Sweep()

	if l.Len() != 1 {
		t.Errorf("Len() = %d after sweep, want 1 (stale key should be gone)", l.Len())
	}
}
