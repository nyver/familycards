// Package model defines the server-side domain types persisted in SQLite.
// The server treats item and blob payloads as opaque bytes; it never
// inspects card contents.
package model

// Vault is the single family safe. All items and users belong to exactly
// one vault.
type Vault struct {
	ID        string
	CreatedAt int64
	LastRev   int64
	MaxUsers  int
}

// User is a family member's account.
type User struct {
	ID              string
	VaultID         string
	Login           string
	DisplayName     string
	PasswordHash    string
	KDFSalt         []byte
	KDFParams       string
	WrappedVaultKey []byte
	WrapNonce       []byte
	CreatedAt       int64
	Disabled        bool
}

// Device is a single installation of the mobile app belonging to a user.
type Device struct {
	ID          string
	UserID      string
	Name        string
	Platform    string
	RefreshHash string
	CreatedAt   int64
	LastSeenAt  int64
	Revoked     bool
}

// Item is one synced, end-to-end encrypted card or settings record.
type Item struct {
	VaultID    string
	ItemID     string
	Kind       string
	Rev        int64
	UpdatedAt  int64
	Deleted    bool
	DeviceID   string
	Nonce      []byte // nil for tombstones
	Ciphertext []byte // nil for tombstones
	BlobRefs   []string
}

// Blob is one encrypted, content-addressed file (a card photo).
type Blob struct {
	VaultID    string
	BlobID     string
	Size       int64
	CreatedAt  int64
	Referenced bool
}

// Invite is a one-time, TTL-bound code that lets a new member join a vault.
type Invite struct {
	CodeHash        string
	VaultID         string
	WrappedVaultKey []byte
	WrapNonce       []byte
	KDFSalt         []byte
	KDFParams       string
	CreatedBy       string
	CreatedAt       int64
	ExpiresAt       int64
	UsedAt          *int64
}

// RecoveryKey is the single per-vault wrapped vault key recoverable via the
// 12-word recovery phrase.
type RecoveryKey struct {
	VaultID         string
	WrappedVaultKey []byte
	WrapNonce       []byte
	KDFSalt         []byte
	KDFParams       string
	CreatedAt       int64
	// VerifierHash is a PHC-formatted argon2id hash of the recovery
	// phrase's canonical string form, letting the server authenticate a
	// redeem attempt without ever storing (or being able to derive) the
	// phrase itself or the vault key.
	VerifierHash string
}

// DeviceInput describes a device presented at bootstrap, login, or invite
// redemption.
type DeviceInput struct {
	ID       string
	Name     string
	Platform string
}
