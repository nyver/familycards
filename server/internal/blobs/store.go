// Package blobs implements content-addressed storage for encrypted card
// photos: atomic on-disk writes, idempotent upload, retrieval, and garbage
// collection of blobs no longer referenced by any live item.
package blobs

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
)

// ErrNotFound is returned when a blob does not exist on disk.
var ErrNotFound = errors.New("blobs: not found")

// Store manages the on-disk layout <baseDir>/<vault_id>/<blob_id[0:2]>/<blob_id[2:4]>/<blob_id>.
type Store struct {
	baseDir string
}

// NewStore builds a Store rooted at baseDir.
func NewStore(baseDir string) *Store {
	return &Store{baseDir: baseDir}
}

// Path returns the on-disk path for a blob, without checking existence.
func (s *Store) Path(vaultID, blobID string) string {
	if len(blobID) < 4 {
		// Defensive: real blob ids are 64-hex-char sha256 digests. A
		// pathologically short id still gets a deterministic (if flat)
		// location rather than panicking on the slice below.
		return filepath.Join(s.baseDir, vaultID, blobID)
	}
	return filepath.Join(s.baseDir, vaultID, blobID[0:2], blobID[2:4], blobID)
}

// Exists reports whether a blob file is already present on disk.
func (s *Store) Exists(vaultID, blobID string) bool {
	_, err := os.Stat(s.Path(vaultID, blobID))
	return err == nil
}

// Write atomically stores data at the blob's path: write to a temp file in
// the same directory, fsync, then rename over the final path. A process
// crash mid-write leaves either nothing or the old file at the final path,
// never a partially-written one.
func (s *Store) Write(vaultID, blobID string, data []byte) error {
	finalPath := s.Path(vaultID, blobID)
	dir := filepath.Dir(finalPath)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("blobs: create directory: %w", err)
	}

	tmp, err := os.CreateTemp(dir, ".upload-*.tmp")
	if err != nil {
		return fmt.Errorf("blobs: create temp file: %w", err)
	}
	tmpPath := tmp.Name()
	// If anything below fails before the rename, clean up the temp file
	// rather than leaving litter in the blob directory.
	succeeded := false
	defer func() {
		if !succeeded {
			os.Remove(tmpPath)
		}
	}()

	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return fmt.Errorf("blobs: write temp file: %w", err)
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return fmt.Errorf("blobs: fsync temp file: %w", err)
	}
	if err := tmp.Close(); err != nil {
		return fmt.Errorf("blobs: close temp file: %w", err)
	}
	if err := os.Rename(tmpPath, finalPath); err != nil {
		return fmt.Errorf("blobs: rename into place: %w", err)
	}
	succeeded = true
	return nil
}

// Read returns a blob's bytes, or ErrNotFound if it is not on disk.
func (s *Store) Read(vaultID, blobID string) ([]byte, error) {
	data, err := os.ReadFile(s.Path(vaultID, blobID))
	if errors.Is(err, os.ErrNotExist) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("blobs: read: %w", err)
	}
	return data, nil
}

// Delete removes a blob file. A missing file is not an error - GC must be
// resilient to a DB row whose file was already removed by hand or by a
// prior, interrupted GC pass.
func (s *Store) Delete(vaultID, blobID string) error {
	err := os.Remove(s.Path(vaultID, blobID))
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("blobs: delete: %w", err)
	}
	return nil
}
