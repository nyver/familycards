package blobs

import (
	"os"
	"path/filepath"
	"testing"
)

func TestStore_WriteReadRoundTrip(t *testing.T) {
	s := NewStore(t.TempDir())
	data := []byte("hello blob")

	if err := s.Write("vault-1", "ab12cd34", data); err != nil {
		t.Fatalf("Write: %v", err)
	}

	got, err := s.Read("vault-1", "ab12cd34")
	if err != nil {
		t.Fatalf("Read: %v", err)
	}
	if string(got) != string(data) {
		t.Errorf("Read() = %q, want %q", got, data)
	}
}

func TestStore_PathLayout(t *testing.T) {
	s := NewStore("/base")
	got := s.Path("vault-1", "ab12cd34ef")
	want := filepath.Join("/base", "vault-1", "ab", "12", "ab12cd34ef")
	if got != want {
		t.Errorf("Path() = %q, want %q", got, want)
	}
}

func TestStore_ReadMissing(t *testing.T) {
	s := NewStore(t.TempDir())
	if _, err := s.Read("vault-1", "doesnotexist"); err != ErrNotFound {
		t.Errorf("Read() error = %v, want ErrNotFound", err)
	}
}

func TestStore_WriteDoesNotLeaveTempFiles(t *testing.T) {
	dir := t.TempDir()
	s := NewStore(dir)
	if err := s.Write("vault-1", "ab12cd34", []byte("data")); err != nil {
		t.Fatalf("Write: %v", err)
	}

	blobDir := filepath.Join(dir, "vault-1", "ab", "12")
	entries, err := os.ReadDir(blobDir)
	if err != nil {
		t.Fatalf("ReadDir: %v", err)
	}
	if len(entries) != 1 {
		t.Errorf("directory has %d entries, want exactly 1 (the final blob, no leftover temp files)", len(entries))
	}
}

func TestStore_DeleteMissingIsNotAnError(t *testing.T) {
	s := NewStore(t.TempDir())
	if err := s.Delete("vault-1", "never-existed"); err != nil {
		t.Errorf("Delete of a missing file should not error, got: %v", err)
	}
}

func TestStore_ExistsReflectsWrite(t *testing.T) {
	s := NewStore(t.TempDir())
	if s.Exists("vault-1", "ab12cd34") {
		t.Error("Exists() should be false before Write")
	}
	if err := s.Write("vault-1", "ab12cd34", []byte("x")); err != nil {
		t.Fatalf("Write: %v", err)
	}
	if !s.Exists("vault-1", "ab12cd34") {
		t.Error("Exists() should be true after Write")
	}
}
