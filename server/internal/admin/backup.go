// Package admin implements operator-only maintenance endpoints, gated by a
// separate X-Admin-Token rather than the regular bearer session tokens.
package admin

import (
	"archive/tar"
	"compress/gzip"
	"context"
	"database/sql"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"familycards/server/internal/crypto"
	"familycards/server/internal/httpapi"
)

// Handlers holds the dependencies for admin endpoints.
type Handlers struct {
	writeDB    *sql.DB
	dbDir      string
	blobDir    string
	adminToken string
}

// NewHandlers builds the admin endpoint handlers. dbDir is the directory
// containing the live database file (backups are written to a "backups"
// subdirectory alongside it, per the deployment layout described in
// docs/DEPLOY.md).
func NewHandlers(writeDB *sql.DB, dbDir, blobDir, adminToken string) *Handlers {
	return &Handlers{writeDB: writeDB, dbDir: dbDir, blobDir: blobDir, adminToken: adminToken}
}

type backupResponse struct {
	DatabaseBackupPath string `json:"database_backup_path"`
	DatabaseSize       int64  `json:"database_size"`
	BlobArchivePath    string `json:"blob_archive_path"`
	BlobArchiveSize    int64  `json:"blob_archive_size"`
}

// Backup handles POST /v1/admin/backup. If no admin token is configured,
// the endpoint reports 404 rather than 401, so its existence is not
// revealed on a deployment that never enabled it.
func (h *Handlers) Backup(w http.ResponseWriter, r *http.Request) {
	if h.adminToken == "" {
		httpapi.WriteError(w, httpapi.ErrNotFound("not found"))
		return
	}

	presented := r.Header.Get("X-Admin-Token")
	if !crypto.ConstantTimeEqual([]byte(h.adminToken), []byte(presented)) {
		httpapi.WriteError(w, httpapi.ErrUnauthorized("invalid admin token"))
		return
	}

	ctx := r.Context()
	ts := time.Now().UTC().Format("20060102-150405")

	backupDir := filepath.Join(h.dbDir, "backups")
	if err := os.MkdirAll(backupDir, 0o755); err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to create backup directory"))
		return
	}

	dbBackupPath := filepath.Join(backupDir, fmt.Sprintf("wallet-%s.db", ts))
	if err := vacuumInto(ctx, h.writeDB, dbBackupPath); err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to back up database"))
		return
	}
	dbInfo, err := os.Stat(dbBackupPath)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("backup file missing after creation"))
		return
	}

	blobArchivePath := filepath.Join(backupDir, fmt.Sprintf("blobs-%s.tar.gz", ts))
	blobSize, err := archiveBlobDir(h.blobDir, blobArchivePath)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to archive blob directory"))
		return
	}

	httpapi.WriteJSON(w, http.StatusOK, backupResponse{
		DatabaseBackupPath: dbBackupPath,
		DatabaseSize:       dbInfo.Size(),
		BlobArchivePath:    blobArchivePath,
		BlobArchiveSize:    blobSize,
	})
}

// vacuumInto uses SQLite's VACUUM INTO to write a consistent, defragmented
// snapshot of the live database to path without blocking writers for
// longer than the vacuum itself takes.
func vacuumInto(ctx context.Context, writeDB *sql.DB, path string) error {
	// VACUUM INTO does not accept a bound parameter for the destination in
	// all SQLite builds; quote the literal ourselves. path is
	// server-generated (a timestamped filename under our own backup
	// directory), never user input, so this is not an injection risk.
	quoted := "'" + escapeSQLiteString(path) + "'"
	_, err := writeDB.ExecContext(ctx, "VACUUM INTO "+quoted)
	if err != nil {
		return fmt.Errorf("admin: vacuum into: %w", err)
	}
	return nil
}

func escapeSQLiteString(s string) string {
	out := make([]byte, 0, len(s))
	for i := 0; i < len(s); i++ {
		if s[i] == '\'' {
			out = append(out, '\'', '\'')
			continue
		}
		out = append(out, s[i])
	}
	return string(out)
}

// archiveBlobDir writes a gzipped tar of blobDir to destPath and returns
// the resulting archive's size. A blobDir that does not exist yet (fresh
// deployment with no photos uploaded) produces a valid, empty archive
// rather than an error.
func archiveBlobDir(blobDir, destPath string) (int64, error) {
	out, err := os.Create(destPath)
	if err != nil {
		return 0, fmt.Errorf("admin: create archive: %w", err)
	}
	defer out.Close()

	gz := gzip.NewWriter(out)
	tw := tar.NewWriter(gz)

	if _, err := os.Stat(blobDir); err == nil {
		err = filepath.Walk(blobDir, func(path string, info os.FileInfo, walkErr error) error {
			if walkErr != nil {
				return walkErr
			}
			if info.IsDir() {
				return nil
			}
			rel, err := filepath.Rel(blobDir, path)
			if err != nil {
				return err
			}
			hdr, err := tar.FileInfoHeader(info, "")
			if err != nil {
				return err
			}
			hdr.Name = filepath.ToSlash(rel)
			if err := tw.WriteHeader(hdr); err != nil {
				return err
			}
			f, err := os.Open(path)
			if err != nil {
				return err
			}
			defer f.Close()
			_, err = io.Copy(tw, f)
			return err
		})
		if err != nil {
			return 0, fmt.Errorf("admin: walk blob dir: %w", err)
		}
	}

	if err := tw.Close(); err != nil {
		return 0, fmt.Errorf("admin: close tar writer: %w", err)
	}
	if err := gz.Close(); err != nil {
		return 0, fmt.Errorf("admin: close gzip writer: %w", err)
	}

	info, err := out.Stat()
	if err != nil {
		return 0, fmt.Errorf("admin: stat archive: %w", err)
	}
	return info.Size(), nil
}
