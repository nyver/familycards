package sync

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
)

// ErrNotFound is returned by repository lookups that find nothing.
var ErrNotFound = errors.New("sync: not found")

type querier interface {
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
	QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
}

// Item mirrors model.Item but lives in this package to avoid a dependency
// on model for the handful of fields the sync engine actually touches
// (kept identical in shape deliberately - see model.Item).
type Item struct {
	VaultID    string
	ItemID     string
	Kind       string
	Rev        int64
	UpdatedAt  int64
	Deleted    bool
	DeviceID   string
	Nonce      []byte
	Ciphertext []byte
	BlobRefs   []string
}

// GetItem looks up the current row for an item, or ErrNotFound.
func GetItem(ctx context.Context, q querier, vaultID, itemID string) (*Item, error) {
	var it Item
	var deleted int
	var blobRefsJSON string
	var nonce, ciphertext []byte
	err := q.QueryRowContext(ctx,
		`SELECT vault_id, item_id, kind, rev, updated_at, deleted, device_id, nonce, ciphertext, blob_refs
		 FROM items WHERE vault_id = ? AND item_id = ?`, vaultID, itemID,
	).Scan(&it.VaultID, &it.ItemID, &it.Kind, &it.Rev, &it.UpdatedAt, &deleted, &it.DeviceID, &nonce, &ciphertext, &blobRefsJSON)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("sync: scan item: %w", err)
	}
	it.Deleted = deleted != 0
	it.Nonce = nonce
	it.Ciphertext = ciphertext
	if err := json.Unmarshal([]byte(blobRefsJSON), &it.BlobRefs); err != nil {
		return nil, fmt.Errorf("sync: unmarshal blob_refs: %w", err)
	}
	return &it, nil
}

// UpsertItem inserts or replaces an item row at the given (already
// assigned) revision.
func UpsertItem(ctx context.Context, tx querier, it Item) error {
	blobRefsJSON, err := json.Marshal(it.BlobRefs)
	if err != nil {
		return fmt.Errorf("sync: marshal blob_refs: %w", err)
	}
	deleted := 0
	if it.Deleted {
		deleted = 1
	}
	_, err = tx.ExecContext(ctx, `
		INSERT INTO items (vault_id, item_id, kind, rev, updated_at, deleted, device_id, nonce, ciphertext, blob_refs)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(vault_id, item_id) DO UPDATE SET
			kind = excluded.kind,
			rev = excluded.rev,
			updated_at = excluded.updated_at,
			deleted = excluded.deleted,
			device_id = excluded.device_id,
			nonce = excluded.nonce,
			ciphertext = excluded.ciphertext,
			blob_refs = excluded.blob_refs`,
		it.VaultID, it.ItemID, it.Kind, it.Rev, it.UpdatedAt, deleted, it.DeviceID, it.Nonce, it.Ciphertext, string(blobRefsJSON),
	)
	if err != nil {
		return fmt.Errorf("sync: upsert item: %w", err)
	}
	return nil
}

// IncrementVaultRev atomically increments and returns a vault's last_rev.
// Must be called inside a write transaction obtained via
// storage.WithImmediateTx, so the read-modify-write is safe even without
// relying on RETURNING semantics.
func IncrementVaultRev(ctx context.Context, tx querier, vaultID string) (int64, error) {
	if _, err := tx.ExecContext(ctx, `UPDATE vaults SET last_rev = last_rev + 1 WHERE id = ?`, vaultID); err != nil {
		return 0, fmt.Errorf("sync: increment vault rev: %w", err)
	}
	var rev int64
	if err := tx.QueryRowContext(ctx, `SELECT last_rev FROM vaults WHERE id = ?`, vaultID).Scan(&rev); err != nil {
		return 0, fmt.Errorf("sync: read vault rev: %w", err)
	}
	return rev, nil
}

// GetVaultRev returns a vault's current last_rev.
func GetVaultRev(ctx context.Context, q querier, vaultID string) (int64, error) {
	var rev int64
	err := q.QueryRowContext(ctx, `SELECT last_rev FROM vaults WHERE id = ?`, vaultID).Scan(&rev)
	if errors.Is(err, sql.ErrNoRows) {
		return 0, ErrNotFound
	}
	return rev, err
}

// ListChanges returns up to limit items with rev > since, ordered by rev
// ascending.
func ListChanges(ctx context.Context, q querier, vaultID string, since int64, limit int) ([]Item, error) {
	rows, err := q.QueryContext(ctx, `
		SELECT vault_id, item_id, kind, rev, updated_at, deleted, device_id, nonce, ciphertext, blob_refs
		FROM items WHERE vault_id = ? AND rev > ? ORDER BY rev ASC LIMIT ?`,
		vaultID, since, limit,
	)
	if err != nil {
		return nil, fmt.Errorf("sync: list changes: %w", err)
	}
	defer rows.Close()

	var items []Item
	for rows.Next() {
		var it Item
		var deleted int
		var blobRefsJSON string
		var nonce, ciphertext []byte
		if err := rows.Scan(&it.VaultID, &it.ItemID, &it.Kind, &it.Rev, &it.UpdatedAt, &deleted, &it.DeviceID, &nonce, &ciphertext, &blobRefsJSON); err != nil {
			return nil, fmt.Errorf("sync: scan change: %w", err)
		}
		it.Deleted = deleted != 0
		it.Nonce = nonce
		it.Ciphertext = ciphertext
		if err := json.Unmarshal([]byte(blobRefsJSON), &it.BlobRefs); err != nil {
			return nil, fmt.Errorf("sync: unmarshal blob_refs: %w", err)
		}
		items = append(items, it)
	}
	return items, rows.Err()
}

// MissingBlobRefs returns the subset of blobIDs that do not exist in the
// vault's blob store, used to reject a push that references blobs the
// client never uploaded.
func MissingBlobRefs(ctx context.Context, q querier, vaultID string, blobIDs []string) ([]string, error) {
	if len(blobIDs) == 0 {
		return nil, nil
	}

	placeholders := make([]string, len(blobIDs))
	args := make([]any, 0, len(blobIDs)+1)
	args = append(args, vaultID)
	for i, id := range blobIDs {
		placeholders[i] = "?"
		args = append(args, id)
	}

	rows, err := q.QueryContext(ctx,
		`SELECT blob_id FROM blobs WHERE vault_id = ? AND blob_id IN (`+strings.Join(placeholders, ",")+`)`,
		args...)
	if err != nil {
		return nil, fmt.Errorf("sync: query existing blobs: %w", err)
	}
	defer rows.Close()

	existing := make(map[string]bool, len(blobIDs))
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, fmt.Errorf("sync: scan blob id: %w", err)
		}
		existing[id] = true
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	var missing []string
	for _, id := range blobIDs {
		if !existing[id] {
			missing = append(missing, id)
		}
	}
	return missing, nil
}

// MarkBlobsReferenced sets referenced=1 for the given blob ids in a vault.
func MarkBlobsReferenced(ctx context.Context, tx querier, vaultID string, blobIDs []string) error {
	if len(blobIDs) == 0 {
		return nil
	}
	placeholders := make([]string, len(blobIDs))
	args := make([]any, 0, len(blobIDs)+1)
	args = append(args, vaultID)
	for i, id := range blobIDs {
		placeholders[i] = "?"
		args = append(args, id)
	}
	_, err := tx.ExecContext(ctx,
		`UPDATE blobs SET referenced = 1 WHERE vault_id = ? AND blob_id IN (`+strings.Join(placeholders, ",")+`)`,
		args...)
	if err != nil {
		return fmt.Errorf("sync: mark blobs referenced: %w", err)
	}
	return nil
}

// DeleteTombstonesOlderThan physically removes tombstone rows (deleted=1)
// whose updated_at is older than cutoffMillis, across all vaults. Returns
// the number of rows removed.
func DeleteTombstonesOlderThan(ctx context.Context, db querier, cutoffMillis int64) (int64, error) {
	res, err := db.ExecContext(ctx, `DELETE FROM items WHERE deleted = 1 AND updated_at < ?`, cutoffMillis)
	if err != nil {
		return 0, fmt.Errorf("sync: delete old tombstones: %w", err)
	}
	return res.RowsAffected()
}
