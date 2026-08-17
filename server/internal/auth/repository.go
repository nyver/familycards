package auth

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"familycards/server/internal/idgen"
	"familycards/server/internal/model"
)

// ErrNotFound is returned by repository lookups that find nothing.
var ErrNotFound = errors.New("auth: not found")

// querier is satisfied by both *sql.DB and *sql.Tx.
type querier interface {
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
	QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
}

// CountUsers returns the total number of user rows, used to gate bootstrap.
func CountUsers(ctx context.Context, q querier) (int, error) {
	var n int
	err := q.QueryRowContext(ctx, "SELECT COUNT(*) FROM users").Scan(&n)
	return n, err
}

// BootstrapParams carries everything needed to create the first vault, user,
// device, and recovery key in one transaction.
type BootstrapParams struct {
	Login           string
	DisplayName     string
	PasswordHash    string
	KDFSalt         []byte
	KDFParams       string
	WrappedVaultKey []byte
	WrapNonce       []byte
	Recovery        RecoveryInput
	Device          model.DeviceInput
	RefreshHash     string
}

// RecoveryInput carries the recovery-phrase-wrapped vault key material.
type RecoveryInput struct {
	WrappedVaultKey []byte
	WrapNonce       []byte
	KDFSalt         []byte
	KDFParams       string
	VerifierHash    string
}

// Bootstrap creates the vault, first user, device, and recovery key row.
// Callers must run this inside a write transaction and must have already
// verified CountUsers == 0 within the same transaction to avoid a
// bootstrap-after-bootstrap race.
func Bootstrap(ctx context.Context, tx querier, p BootstrapParams) (vaultID, userID, deviceID string, err error) {
	now := idgen.NowUnix()
	vaultID = idgen.NewID()
	userID = idgen.NewID()
	deviceID = p.Device.ID
	if deviceID == "" {
		deviceID = idgen.NewID()
	}

	if _, err = tx.ExecContext(ctx,
		`INSERT INTO vaults (id, created_at, last_rev, max_users) VALUES (?, ?, 0, 5)`,
		vaultID, now,
	); err != nil {
		return "", "", "", fmt.Errorf("auth: insert vault: %w", err)
	}

	if _, err = tx.ExecContext(ctx,
		`INSERT INTO users (id, vault_id, login, display_name, password_hash, kdf_salt, kdf_params, wrapped_vault_key, wrap_nonce, created_at, disabled)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)`,
		userID, vaultID, p.Login, p.DisplayName, p.PasswordHash, p.KDFSalt, p.KDFParams, p.WrappedVaultKey, p.WrapNonce, now,
	); err != nil {
		return "", "", "", fmt.Errorf("auth: insert user: %w", err)
	}

	if _, err = tx.ExecContext(ctx,
		`INSERT INTO devices (id, user_id, name, platform, refresh_hash, created_at, last_seen_at, revoked)
		 VALUES (?, ?, ?, ?, ?, ?, ?, 0)`,
		deviceID, userID, p.Device.Name, p.Device.Platform, p.RefreshHash, now, now,
	); err != nil {
		return "", "", "", fmt.Errorf("auth: insert device: %w", err)
	}

	if _, err = tx.ExecContext(ctx,
		`INSERT INTO recovery_keys (vault_id, wrapped_vault_key, wrap_nonce, kdf_salt, kdf_params, created_at, verifier_hash)
		 VALUES (?, ?, ?, ?, ?, ?, ?)`,
		vaultID, p.Recovery.WrappedVaultKey, p.Recovery.WrapNonce, p.Recovery.KDFSalt, p.Recovery.KDFParams, now, p.Recovery.VerifierHash,
	); err != nil {
		return "", "", "", fmt.Errorf("auth: insert recovery key: %w", err)
	}

	return vaultID, userID, deviceID, nil
}

// CreateUserInVault creates a new user in an existing vault - the path used
// by invite redemption, as opposed to Bootstrap which also creates the
// vault itself.
func CreateUserInVault(ctx context.Context, tx querier, vaultID, login, displayName, passwordHash string, kdfSalt []byte, kdfParams string, wrappedVK, wrapNonce []byte) (userID string, err error) {
	userID = idgen.NewID()
	_, err = tx.ExecContext(ctx,
		`INSERT INTO users (id, vault_id, login, display_name, password_hash, kdf_salt, kdf_params, wrapped_vault_key, wrap_nonce, created_at, disabled)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)`,
		userID, vaultID, login, displayName, passwordHash, kdfSalt, kdfParams, wrappedVK, wrapNonce, idgen.NowUnix(),
	)
	if err != nil {
		return "", fmt.Errorf("auth: insert user: %w", err)
	}
	return userID, nil
}

// GetUserByLogin looks up a user case-insensitively (the login column is
// COLLATE NOCASE). Returns ErrNotFound if no such user exists.
func GetUserByLogin(ctx context.Context, q querier, login string) (*model.User, error) {
	row := q.QueryRowContext(ctx,
		`SELECT id, vault_id, login, display_name, password_hash, kdf_salt, kdf_params, wrapped_vault_key, wrap_nonce, created_at, disabled
		 FROM users WHERE login = ?`, login)
	return scanUser(row)
}

// GetUserByID looks up a user by primary key.
func GetUserByID(ctx context.Context, q querier, userID string) (*model.User, error) {
	row := q.QueryRowContext(ctx,
		`SELECT id, vault_id, login, display_name, password_hash, kdf_salt, kdf_params, wrapped_vault_key, wrap_nonce, created_at, disabled
		 FROM users WHERE id = ?`, userID)
	return scanUser(row)
}

func scanUser(row *sql.Row) (*model.User, error) {
	var u model.User
	var disabled int
	err := row.Scan(&u.ID, &u.VaultID, &u.Login, &u.DisplayName, &u.PasswordHash, &u.KDFSalt, &u.KDFParams, &u.WrappedVaultKey, &u.WrapNonce, &u.CreatedAt, &disabled)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("auth: scan user: %w", err)
	}
	u.Disabled = disabled != 0
	return &u, nil
}

// GetVault looks up a vault by primary key.
func GetVault(ctx context.Context, q querier, vaultID string) (*model.Vault, error) {
	var v model.Vault
	err := q.QueryRowContext(ctx, `SELECT id, created_at, last_rev, max_users FROM vaults WHERE id = ?`, vaultID).
		Scan(&v.ID, &v.CreatedAt, &v.LastRev, &v.MaxUsers)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("auth: scan vault: %w", err)
	}
	return &v, nil
}

// CountActiveUsers returns the number of non-disabled users in a vault.
func CountActiveUsers(ctx context.Context, q querier, vaultID string) (int, error) {
	var n int
	err := q.QueryRowContext(ctx, `SELECT COUNT(*) FROM users WHERE vault_id = ? AND disabled = 0`, vaultID).Scan(&n)
	return n, err
}

// CountActiveDevices returns the number of non-revoked devices belonging to
// users of a vault.
func CountActiveDevices(ctx context.Context, q querier, vaultID string) (int, error) {
	var n int
	err := q.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM devices d
		JOIN users u ON u.id = d.user_id
		WHERE u.vault_id = ? AND d.revoked = 0`, vaultID).Scan(&n)
	return n, err
}

// UpsertLoginDevice creates a device row for a login/redeem/bootstrap flow.
func CreateDevice(ctx context.Context, tx querier, userID string, in model.DeviceInput, refreshHash string) (deviceID string, err error) {
	deviceID = in.ID
	if deviceID == "" {
		deviceID = idgen.NewID()
	}
	now := idgen.NowUnix()
	_, err = tx.ExecContext(ctx,
		`INSERT INTO devices (id, user_id, name, platform, refresh_hash, created_at, last_seen_at, revoked)
		 VALUES (?, ?, ?, ?, ?, ?, ?, 0)`,
		deviceID, userID, in.Name, in.Platform, refreshHash, now, now)
	if err != nil {
		return "", fmt.Errorf("auth: insert device: %w", err)
	}
	return deviceID, nil
}

// GetDeviceByRefreshHash finds the device currently holding this refresh
// token hash. Returns ErrNotFound if none matches (including revoked
// devices, whose refresh_hash no longer authorizes anything meaningful but
// is still compared so callers can detect reuse explicitly if needed).
func GetDeviceByRefreshHash(ctx context.Context, q querier, hash string) (*model.Device, error) {
	row := q.QueryRowContext(ctx,
		`SELECT id, user_id, name, platform, refresh_hash, created_at, last_seen_at, revoked
		 FROM devices WHERE refresh_hash = ?`, hash)
	return scanDevice(row)
}

// GetDeviceByID looks up a device by primary key.
func GetDeviceByID(ctx context.Context, q querier, deviceID string) (*model.Device, error) {
	row := q.QueryRowContext(ctx,
		`SELECT id, user_id, name, platform, refresh_hash, created_at, last_seen_at, revoked
		 FROM devices WHERE id = ?`, deviceID)
	return scanDevice(row)
}

func scanDevice(row *sql.Row) (*model.Device, error) {
	var d model.Device
	var revoked int
	err := row.Scan(&d.ID, &d.UserID, &d.Name, &d.Platform, &d.RefreshHash, &d.CreatedAt, &d.LastSeenAt, &revoked)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("auth: scan device: %w", err)
	}
	d.Revoked = revoked != 0
	return &d, nil
}

// UpdateDeviceRefreshHash rotates a device's stored refresh token hash and
// bumps last_seen_at.
func UpdateDeviceRefreshHash(ctx context.Context, tx querier, deviceID, newHash string) error {
	_, err := tx.ExecContext(ctx,
		`UPDATE devices SET refresh_hash = ?, last_seen_at = ? WHERE id = ?`,
		newHash, idgen.NowUnix(), deviceID)
	return err
}

// TouchDevice bumps last_seen_at without changing the refresh hash.
func TouchDevice(ctx context.Context, tx querier, deviceID string) error {
	_, err := tx.ExecContext(ctx, `UPDATE devices SET last_seen_at = ? WHERE id = ?`, idgen.NowUnix(), deviceID)
	return err
}

// RevokeDevice marks a single device revoked.
func RevokeDevice(ctx context.Context, tx querier, deviceID string) error {
	_, err := tx.ExecContext(ctx, `UPDATE devices SET revoked = 1 WHERE id = ?`, deviceID)
	return err
}

// RevokeAllUserDevices marks every device of a user revoked, used when
// refresh token reuse is detected or a member is removed.
func RevokeAllUserDevices(ctx context.Context, tx querier, userID string) error {
	_, err := tx.ExecContext(ctx, `UPDATE devices SET revoked = 1 WHERE user_id = ?`, userID)
	return err
}

// UpdateUserPasswordAndWrap atomically changes the password hash and the
// wrapped-vault-key envelope, which must always move together.
func UpdateUserPasswordAndWrap(ctx context.Context, tx querier, userID, passwordHash string, kdfSalt []byte, kdfParams string, wrappedVK, wrapNonce []byte) error {
	_, err := tx.ExecContext(ctx,
		`UPDATE users SET password_hash = ?, kdf_salt = ?, kdf_params = ?, wrapped_vault_key = ?, wrap_nonce = ? WHERE id = ?`,
		passwordHash, kdfSalt, kdfParams, wrappedVK, wrapNonce, userID)
	return err
}

// SetUserDisabled toggles the disabled flag on a user.
func SetUserDisabled(ctx context.Context, tx querier, userID string, disabled bool) error {
	v := 0
	if disabled {
		v = 1
	}
	_, err := tx.ExecContext(ctx, `UPDATE users SET disabled = ? WHERE id = ?`, v, userID)
	return err
}

// ListMembers returns every user in a vault with their devices, ordered by
// created_at.
func ListMembers(ctx context.Context, q querier, vaultID string) ([]model.User, error) {
	rows, err := q.QueryContext(ctx,
		`SELECT id, vault_id, login, display_name, password_hash, kdf_salt, kdf_params, wrapped_vault_key, wrap_nonce, created_at, disabled
		 FROM users WHERE vault_id = ? ORDER BY created_at ASC`, vaultID)
	if err != nil {
		return nil, fmt.Errorf("auth: list members: %w", err)
	}
	defer rows.Close()

	var users []model.User
	for rows.Next() {
		var u model.User
		var disabled int
		if err := rows.Scan(&u.ID, &u.VaultID, &u.Login, &u.DisplayName, &u.PasswordHash, &u.KDFSalt, &u.KDFParams, &u.WrappedVaultKey, &u.WrapNonce, &u.CreatedAt, &disabled); err != nil {
			return nil, fmt.Errorf("auth: scan member: %w", err)
		}
		u.Disabled = disabled != 0
		users = append(users, u)
	}
	return users, rows.Err()
}

// ListDevicesByUser returns every device belonging to a user.
func ListDevicesByUser(ctx context.Context, q querier, userID string) ([]model.Device, error) {
	rows, err := q.QueryContext(ctx,
		`SELECT id, user_id, name, platform, refresh_hash, created_at, last_seen_at, revoked
		 FROM devices WHERE user_id = ? ORDER BY created_at ASC`, userID)
	if err != nil {
		return nil, fmt.Errorf("auth: list devices: %w", err)
	}
	defer rows.Close()

	var devices []model.Device
	for rows.Next() {
		var d model.Device
		var revoked int
		if err := rows.Scan(&d.ID, &d.UserID, &d.Name, &d.Platform, &d.RefreshHash, &d.CreatedAt, &d.LastSeenAt, &revoked); err != nil {
			return nil, fmt.Errorf("auth: scan device: %w", err)
		}
		d.Revoked = revoked != 0
		devices = append(devices, d)
	}
	return devices, rows.Err()
}

// GetRecoveryKey looks up the single recovery key row for a vault.
func GetRecoveryKey(ctx context.Context, q querier, vaultID string) (*model.RecoveryKey, error) {
	var r model.RecoveryKey
	err := q.QueryRowContext(ctx,
		`SELECT vault_id, wrapped_vault_key, wrap_nonce, kdf_salt, kdf_params, created_at, verifier_hash FROM recovery_keys WHERE vault_id = ?`,
		vaultID,
	).Scan(&r.VaultID, &r.WrappedVaultKey, &r.WrapNonce, &r.KDFSalt, &r.KDFParams, &r.CreatedAt, &r.VerifierHash)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("auth: scan recovery key: %w", err)
	}
	return &r, nil
}

// GetRecoveryKeyByLogin looks up the recovery key for the vault that owns
// login (case-insensitively), used by the recovery-by-phrase flow which
// has no other identifier to start from.
func GetRecoveryKeyByLogin(ctx context.Context, q querier, login string) (*model.RecoveryKey, error) {
	var r model.RecoveryKey
	err := q.QueryRowContext(ctx, `
		SELECT rk.vault_id, rk.wrapped_vault_key, rk.wrap_nonce, rk.kdf_salt, rk.kdf_params, rk.created_at, rk.verifier_hash
		FROM recovery_keys rk
		JOIN users u ON u.vault_id = rk.vault_id
		WHERE u.login = ?`, login,
	).Scan(&r.VaultID, &r.WrappedVaultKey, &r.WrapNonce, &r.KDFSalt, &r.KDFParams, &r.CreatedAt, &r.VerifierHash)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("auth: scan recovery key by login: %w", err)
	}
	return &r, nil
}

// RetireRefreshHash records a hash that is being rotated away from, so a
// later replay of it can be recognized as reuse rather than treated as an
// unknown token.
func RetireRefreshHash(ctx context.Context, tx querier, userID, hash string) error {
	_, err := tx.ExecContext(ctx,
		`INSERT OR IGNORE INTO retired_refresh_tokens (hash, user_id, retired_at) VALUES (?, ?, ?)`,
		hash, userID, idgen.NowUnix())
	return err
}

// RetiredRefreshTokenUser returns the user id that a retired (rotated-away)
// refresh token hash belonged to, or ErrNotFound if the hash was never
// retired.
func RetiredRefreshTokenUser(ctx context.Context, q querier, hash string) (string, error) {
	var userID string
	err := q.QueryRowContext(ctx, `SELECT user_id FROM retired_refresh_tokens WHERE hash = ?`, hash).Scan(&userID)
	if errors.Is(err, sql.ErrNoRows) {
		return "", ErrNotFound
	}
	if err != nil {
		return "", fmt.Errorf("auth: scan retired refresh token: %w", err)
	}
	return userID, nil
}

// FindUserDevice looks up a device by id, but only returns it if it belongs
// to userID - used to safely reuse a client-supplied device id at login.
func FindUserDevice(ctx context.Context, q querier, userID, deviceID string) (*model.Device, error) {
	d, err := GetDeviceByID(ctx, q, deviceID)
	if err != nil {
		return nil, err
	}
	if d.UserID != userID {
		return nil, ErrNotFound
	}
	return d, nil
}
