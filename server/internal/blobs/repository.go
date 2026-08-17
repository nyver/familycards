package blobs

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
)

type querier interface {
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
	QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
}

// Meta is a blob's metadata row.
type Meta struct {
	VaultID    string
	BlobID     string
	Size       int64
	CreatedAt  int64
	Referenced bool
}

// GetMeta looks up a blob's metadata scoped to a vault. Returns
// (nil, nil) if not found (not an error - callers decide what that means).
func GetMeta(ctx context.Context, q querier, vaultID, blobID string) (*Meta, error) {
	var m Meta
	var referenced int
	err := q.QueryRowContext(ctx,
		`SELECT vault_id, blob_id, size, created_at, referenced FROM blobs WHERE vault_id = ? AND blob_id = ?`,
		vaultID, blobID,
	).Scan(&m.VaultID, &m.BlobID, &m.Size, &m.CreatedAt, &referenced)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("blobs: scan meta: %w", err)
	}
	m.Referenced = referenced != 0
	return &m, nil
}

// InsertIfAbsent inserts a blob metadata row if one does not already exist
// for (vaultID, blobID). Returns created=true only if this call inserted
// the row.
func InsertIfAbsent(ctx context.Context, tx querier, vaultID, blobID string, size, createdAt int64) (created bool, err error) {
	res, err := tx.ExecContext(ctx,
		`INSERT OR IGNORE INTO blobs (vault_id, blob_id, size, created_at, referenced) VALUES (?, ?, ?, ?, 0)`,
		vaultID, blobID, size, createdAt)
	if err != nil {
		return false, fmt.Errorf("blobs: insert meta: %w", err)
	}
	n, err := res.RowsAffected()
	if err != nil {
		return false, err
	}
	return n > 0, nil
}

// ListUnreferencedOlderThan returns blobs with referenced=0 whose
// created_at is older than cutoffUnix - candidates for GC because they
// were uploaded but never confirmed by a push.
func ListUnreferencedOlderThan(ctx context.Context, q querier, cutoffUnix int64) ([]Meta, error) {
	return queryBlobs(ctx, q, `SELECT vault_id, blob_id, size, created_at, referenced FROM blobs WHERE referenced = 0 AND created_at < ?`, cutoffUnix)
}

// ListReferencedOlderThan returns blobs with referenced=1 whose created_at
// is older than cutoffUnix - candidates for the orphan GC pass, which then
// checks whether any live item still points at each one.
func ListReferencedOlderThan(ctx context.Context, q querier, cutoffUnix int64) ([]Meta, error) {
	return queryBlobs(ctx, q, `SELECT vault_id, blob_id, size, created_at, referenced FROM blobs WHERE referenced = 1 AND created_at < ?`, cutoffUnix)
}

func queryBlobs(ctx context.Context, q querier, query string, args ...any) ([]Meta, error) {
	rows, err := q.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("blobs: query: %w", err)
	}
	defer rows.Close()

	var out []Meta
	for rows.Next() {
		var m Meta
		var referenced int
		if err := rows.Scan(&m.VaultID, &m.BlobID, &m.Size, &m.CreatedAt, &referenced); err != nil {
			return nil, fmt.Errorf("blobs: scan: %w", err)
		}
		m.Referenced = referenced != 0
		out = append(out, m)
	}
	return out, rows.Err()
}

// DeleteMeta removes a blob's metadata row unconditionally.
func DeleteMeta(ctx context.Context, tx querier, vaultID, blobID string) error {
	_, err := tx.ExecContext(ctx, `DELETE FROM blobs WHERE vault_id = ? AND blob_id = ?`, vaultID, blobID)
	if err != nil {
		return fmt.Errorf("blobs: delete meta: %w", err)
	}
	return nil
}

// DeleteMetaIfUnreferenced removes a blob's metadata row only if it is
// still referenced=0 at delete time, re-checking the condition inside the
// same write transaction that performs the delete. This closes the race
// where a push confirms (references) the blob between GC listing its
// candidates and GC getting around to deleting this one. Returns whether a
// row was actually deleted.
func DeleteMetaIfUnreferenced(ctx context.Context, tx querier, vaultID, blobID string) (bool, error) {
	res, err := tx.ExecContext(ctx, `DELETE FROM blobs WHERE vault_id = ? AND blob_id = ? AND referenced = 0`, vaultID, blobID)
	if err != nil {
		return false, fmt.Errorf("blobs: conditional delete meta: %w", err)
	}
	n, err := res.RowsAffected()
	if err != nil {
		return false, err
	}
	return n > 0, nil
}

// IsBlobLive reports whether any non-deleted item in the vault currently
// references blobID. blob_refs is stored as a JSON array of fixed-length
// (64 hex char) ids, so a LIKE match on the quoted id is an exact
// membership test with no risk of one id being a substring of another.
func IsBlobLive(ctx context.Context, q querier, vaultID, blobID string) (bool, error) {
	var n int
	err := q.QueryRowContext(ctx,
		`SELECT COUNT(*) FROM items WHERE vault_id = ? AND deleted = 0 AND blob_refs LIKE '%"' || ? || '"%'`,
		vaultID, blobID,
	).Scan(&n)
	if err != nil {
		return false, fmt.Errorf("blobs: check blob liveness: %w", err)
	}
	return n > 0, nil
}

// LiveBlobRefs returns the set of blob ids referenced by any non-deleted
// item in a vault, used by the orphan GC pass to decide whether a
// referenced=1 blob still has a live owner.
func LiveBlobRefs(ctx context.Context, q querier, vaultID string) (map[string]bool, error) {
	rows, err := q.QueryContext(ctx, `SELECT blob_refs FROM items WHERE vault_id = ? AND deleted = 0`, vaultID)
	if err != nil {
		return nil, fmt.Errorf("blobs: query item blob_refs: %w", err)
	}
	defer rows.Close()

	live := make(map[string]bool)
	for rows.Next() {
		var raw string
		if err := rows.Scan(&raw); err != nil {
			return nil, fmt.Errorf("blobs: scan blob_refs: %w", err)
		}
		var refs []string
		if err := json.Unmarshal([]byte(raw), &refs); err != nil {
			return nil, fmt.Errorf("blobs: unmarshal blob_refs %q: %w", raw, err)
		}
		for _, id := range refs {
			live[strings.TrimSpace(id)] = true
		}
	}
	return live, rows.Err()
}

// DistinctVaultsWithBlobs returns every vault_id that has at least one blob
// row, used to scope the orphan GC pass per vault.
func DistinctVaultsWithBlobs(ctx context.Context, q querier) ([]string, error) {
	rows, err := q.QueryContext(ctx, `SELECT DISTINCT vault_id FROM blobs`)
	if err != nil {
		return nil, fmt.Errorf("blobs: list vaults: %w", err)
	}
	defer rows.Close()

	var vaults []string
	for rows.Next() {
		var v string
		if err := rows.Scan(&v); err != nil {
			return nil, fmt.Errorf("blobs: scan vault id: %w", err)
		}
		vaults = append(vaults, v)
	}
	return vaults, rows.Err()
}
