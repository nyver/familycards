package sync

import (
	"encoding/json"
	"os"
	"testing"
)

type vectorFile struct {
	Cases []struct {
		Name             string `json:"name"`
		CurrentExists    bool   `json:"current_exists"`
		CurrentRev       int64  `json:"current_rev"`
		CurrentUpdatedAt int64  `json:"current_updated_at"`
		CurrentDeviceID  string `json:"current_device_id"`
		BaseRev          int64  `json:"base_rev"`
		UpdatedAt        int64  `json:"updated_at"`
		DeviceID         string `json:"device_id"`
		Accept           bool   `json:"accept"`
	} `json:"cases"`
}

// TestResolve_SharedVectors runs the canonical LWW test vectors shared with
// the Dart client (testdata/lww_vectors.json at the repo root). Divergence
// here means two offline devices would not converge after sync.
func TestResolve_SharedVectors(t *testing.T) {
	data, err := os.ReadFile("../../../testdata/lww_vectors.json")
	if err != nil {
		t.Fatalf("read shared vectors: %v", err)
	}
	var vf vectorFile
	if err := json.Unmarshal(data, &vf); err != nil {
		t.Fatalf("parse shared vectors: %v", err)
	}
	if len(vf.Cases) < 12 {
		t.Fatalf("expected at least 12 shared vectors, got %d", len(vf.Cases))
	}

	for _, c := range vf.Cases {
		t.Run(c.Name, func(t *testing.T) {
			cur := CurrentItem{
				Exists:    c.CurrentExists,
				Rev:       c.CurrentRev,
				UpdatedAt: c.CurrentUpdatedAt,
				DeviceID:  c.CurrentDeviceID,
			}
			incoming := Incoming{
				BaseRev:   c.BaseRev,
				UpdatedAt: c.UpdatedAt,
				DeviceID:  c.DeviceID,
			}
			got := Resolve(cur, incoming)
			if got != c.Accept {
				t.Errorf("Resolve() = %v, want %v", got, c.Accept)
			}
		})
	}
}

func TestResolve_AdditionalEdgeCases(t *testing.T) {
	cases := []struct {
		name string
		cur  CurrentItem
		in   Incoming
		want bool
	}{
		{
			name: "current absent zero updated_at zero device still accepts new item",
			cur:  CurrentItem{Exists: false},
			in:   Incoming{BaseRev: 0, UpdatedAt: 0, DeviceID: ""},
			want: true,
		},
		{
			name: "exact base_rev match ignores updated_at entirely",
			cur:  CurrentItem{Exists: true, Rev: 3, UpdatedAt: 999999, DeviceID: "z"},
			in:   Incoming{BaseRev: 3, UpdatedAt: 1, DeviceID: "a"},
			want: true,
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := Resolve(c.cur, c.in); got != c.want {
				t.Errorf("Resolve() = %v, want %v", got, c.want)
			}
		})
	}
}
