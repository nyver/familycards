// Package membership implements family composition: issuing and redeeming
// invite codes, listing members, and revoking access.
package membership

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"familycards/server/internal/model"
)

// ErrNotFound is returned by repository lookups that find nothing.
var ErrNotFound = errors.New("membership: not found")

type querier interface {
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
	QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
}

// CountActiveInvites returns the number of invites for a vault that are
// neither used nor expired - these count against the member quota just
// like existing users.
func CountActiveInvites(ctx context.Context, q querier, vaultID string, now int64) (int, error) {
	var n int
	err := q.QueryRowContext(ctx,
		`SELECT COUNT(*) FROM invites WHERE vault_id = ? AND used_at IS NULL AND expires_at > ?`,
		vaultID, now).Scan(&n)
	return n, err
}

// CreateInvite inserts a new invite row.
func CreateInvite(ctx context.Context, tx querier, in model.Invite) error {
	_, err := tx.ExecContext(ctx,
		`INSERT INTO invites (code_hash, vault_id, wrapped_vault_key, wrap_nonce, kdf_salt, kdf_params, created_by, created_at, expires_at, used_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)`,
		in.CodeHash, in.VaultID, in.WrappedVaultKey, in.WrapNonce, in.KDFSalt, in.KDFParams, in.CreatedBy, in.CreatedAt, in.ExpiresAt)
	if err != nil {
		return fmt.Errorf("membership: insert invite: %w", err)
	}
	return nil
}

// GetInvite looks up an invite by its code hash.
func GetInvite(ctx context.Context, q querier, codeHash string) (*model.Invite, error) {
	var inv model.Invite
	var usedAt sql.NullInt64
	err := q.QueryRowContext(ctx,
		`SELECT code_hash, vault_id, wrapped_vault_key, wrap_nonce, kdf_salt, kdf_params, created_by, created_at, expires_at, used_at
		 FROM invites WHERE code_hash = ?`, codeHash,
	).Scan(&inv.CodeHash, &inv.VaultID, &inv.WrappedVaultKey, &inv.WrapNonce, &inv.KDFSalt, &inv.KDFParams, &inv.CreatedBy, &inv.CreatedAt, &inv.ExpiresAt, &usedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("membership: scan invite: %w", err)
	}
	if usedAt.Valid {
		inv.UsedAt = &usedAt.Int64
	}
	return &inv, nil
}

// MarkInviteUsed sets used_at on an invite, but only if it is still
// unused - the WHERE clause makes concurrent redemption attempts race
// safely: at most one UPDATE affects a row.
func MarkInviteUsed(ctx context.Context, tx querier, codeHash string, usedAt int64) (bool, error) {
	res, err := tx.ExecContext(ctx, `UPDATE invites SET used_at = ? WHERE code_hash = ? AND used_at IS NULL`, usedAt, codeHash)
	if err != nil {
		return false, fmt.Errorf("membership: mark invite used: %w", err)
	}
	n, err := res.RowsAffected()
	if err != nil {
		return false, err
	}
	return n > 0, nil
}

// DeleteInvite removes an invite belonging to vaultID. Returns false if no
// matching row existed.
func DeleteInvite(ctx context.Context, tx querier, codeHash, vaultID string) (bool, error) {
	res, err := tx.ExecContext(ctx, `DELETE FROM invites WHERE code_hash = ? AND vault_id = ?`, codeHash, vaultID)
	if err != nil {
		return false, fmt.Errorf("membership: delete invite: %w", err)
	}
	n, err := res.RowsAffected()
	if err != nil {
		return false, err
	}
	return n > 0, nil
}
