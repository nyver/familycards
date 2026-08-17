// Package sync implements the delta synchronization protocol: revision
// assignment, paginated change delivery, batch push, and the deterministic
// last-writer-wins conflict rule. The conflict rule is deliberately a pure
// function with no I/O, because the client must implement the identical
// rule independently (see testdata/lww_vectors.json at the repo root) - any
// divergence between the two would mean two offline devices never converge
// to the same state.
package sync

// CurrentItem describes the server's existing record for an item, as seen
// by the conflict resolver. Exists is false when the server has no record
// of the item at all (never pushed, or physically purged).
type CurrentItem struct {
	Exists    bool
	Rev       int64
	UpdatedAt int64
	DeviceID  string
}

// Incoming describes one item from a client's push request.
type Incoming struct {
	BaseRev   int64
	UpdatedAt int64
	DeviceID  string
}

// Resolve reports whether incoming should be accepted (stored, replacing
// cur) per the spec's deterministic rule:
//
//   - no current record: accept iff BaseRev == 0 (a genuinely new item)
//   - current.Rev == incoming.BaseRev: accept (client saw the latest state)
//   - otherwise: accept iff (UpdatedAt, DeviceID) sorts strictly after
//     (cur.UpdatedAt, cur.DeviceID)
//
// This function is pure and side-effect free so it can be exhaustively
// table-tested and so its logic can be verified against the same fixture
// data the Dart client tests against.
func Resolve(cur CurrentItem, incoming Incoming) bool {
	if !cur.Exists {
		return incoming.BaseRev == 0
	}
	if cur.Rev == incoming.BaseRev {
		return true
	}
	return wins(incoming.UpdatedAt, incoming.DeviceID, cur.UpdatedAt, cur.DeviceID)
}

// wins reports whether (aUpdatedAt, aDeviceID) sorts strictly after
// (bUpdatedAt, bDeviceID): greater updated_at wins outright; on a tie,
// the lexicographically greater device_id wins.
func wins(aUpdatedAt int64, aDeviceID string, bUpdatedAt int64, bDeviceID string) bool {
	if aUpdatedAt != bUpdatedAt {
		return aUpdatedAt > bUpdatedAt
	}
	return aDeviceID > bDeviceID
}
