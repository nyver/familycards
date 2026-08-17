package admin_test

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"familycards/server/internal/admin"
	"familycards/server/internal/migrations"
	"familycards/server/internal/storage"

	_ "modernc.org/sqlite"
)

func newTestDB(t *testing.T) (*storage.DB, string) {
	t.Helper()
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "wallet.db")
	db, err := storage.Open(dbPath)
	if err != nil {
		t.Fatalf("storage.Open: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	if err := migrations.Apply(context.Background(), db.Write); err != nil {
		t.Fatalf("migrations.Apply: %v", err)
	}
	return db, dir
}

type backupResponse struct {
	DatabaseBackupPath string `json:"database_backup_path"`
	DatabaseSize       int64  `json:"database_size"`
	BlobArchivePath    string `json:"blob_archive_path"`
	BlobArchiveSize    int64  `json:"blob_archive_size"`
}

func TestBackup_Success(t *testing.T) {
	db, dir := newTestDB(t)
	blobDir := filepath.Join(dir, "blobs")
	if err := os.MkdirAll(filepath.Join(blobDir, "v1", "ab", "cd"), 0o755); err != nil {
		t.Fatalf("mkdir blob dir: %v", err)
	}
	if err := os.WriteFile(filepath.Join(blobDir, "v1", "ab", "cd", "abcd1234"), []byte("photo bytes"), 0o644); err != nil {
		t.Fatalf("write blob file: %v", err)
	}

	// Put some data in the live DB so we can confirm the backup contains it.
	if _, err := db.Write.Exec(`INSERT INTO vaults (id, created_at, last_rev, max_users) VALUES ('vault-1', 1000, 0, 5)`); err != nil {
		t.Fatalf("insert vault: %v", err)
	}

	h := admin.NewHandlers(db.Write, dir, blobDir, "secret-admin-token")

	req := httptest.NewRequest(http.MethodPost, "/v1/admin/backup", nil)
	req.Header.Set("X-Admin-Token", "secret-admin-token")
	w := httptest.NewRecorder()
	h.Backup(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200, body=%s", w.Code, w.Body.String())
	}
	var resp backupResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	// The backup file must exist and open as a valid SQLite DB containing
	// the same data as the live database.
	if _, err := os.Stat(resp.DatabaseBackupPath); err != nil {
		t.Fatalf("backup db file missing: %v", err)
	}
	backupDB, err := storage.Open(resp.DatabaseBackupPath)
	if err != nil {
		t.Fatalf("open backup db: %v", err)
	}
	defer backupDB.Close()

	var vaultID string
	if err := backupDB.Read.QueryRow(`SELECT id FROM vaults WHERE id = 'vault-1'`).Scan(&vaultID); err != nil {
		t.Fatalf("backup db missing expected data: %v", err)
	}
	if vaultID != "vault-1" {
		t.Errorf("backup db vault id = %q, want vault-1", vaultID)
	}

	if resp.BlobArchiveSize == 0 {
		t.Error("blob archive size should be non-zero (it contains one file)")
	}
	if _, err := os.Stat(resp.BlobArchivePath); err != nil {
		t.Fatalf("blob archive missing: %v", err)
	}
}

func TestBackup_WrongToken(t *testing.T) {
	db, dir := newTestDB(t)
	h := admin.NewHandlers(db.Write, dir, filepath.Join(dir, "blobs"), "secret-admin-token")

	req := httptest.NewRequest(http.MethodPost, "/v1/admin/backup", nil)
	req.Header.Set("X-Admin-Token", "wrong-token")
	w := httptest.NewRecorder()
	h.Backup(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("status = %d, want 401", w.Code)
	}
}

func TestBackup_NotConfigured(t *testing.T) {
	db, dir := newTestDB(t)
	h := admin.NewHandlers(db.Write, dir, filepath.Join(dir, "blobs"), "")

	req := httptest.NewRequest(http.MethodPost, "/v1/admin/backup", nil)
	req.Header.Set("X-Admin-Token", "anything")
	w := httptest.NewRecorder()
	h.Backup(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("status = %d, want 404", w.Code)
	}
}
