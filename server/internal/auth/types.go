package auth

import "encoding/json"

type deviceDTO struct {
	ID       string `json:"id,omitempty"`
	Name     string `json:"name"`
	Platform string `json:"platform"`
}

type recoveryDTO struct {
	WrappedVaultKey string          `json:"wrapped_vault_key"`
	WrapNonce       string          `json:"wrap_nonce"`
	KDFSalt         string          `json:"kdf_salt"`
	KDFParams       json.RawMessage `json:"kdf_params"`
	// Verifier is the recovery phrase's canonical string form, sent once
	// over TLS at bootstrap time so the server can hash and store it -
	// the same trust model already used for Password below. Never stored
	// or logged in plaintext; only its argon2id hash is persisted.
	Verifier string `json:"verifier"`
}

type bootstrapRequest struct {
	Login           string          `json:"login"`
	DisplayName     string          `json:"display_name"`
	Password        string          `json:"password"`
	KDFSalt         string          `json:"kdf_salt"`
	KDFParams       json.RawMessage `json:"kdf_params"`
	WrappedVaultKey string          `json:"wrapped_vault_key"`
	WrapNonce       string          `json:"wrap_nonce"`
	Recovery        recoveryDTO     `json:"recovery"`
	Device          deviceDTO       `json:"device"`
}

type bootstrapResponse struct {
	UserID       string `json:"user_id"`
	VaultID      string `json:"vault_id"`
	DeviceID     string `json:"device_id"`
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
}

type preloginRequest struct {
	Login string `json:"login"`
}

type preloginResponse struct {
	KDFSalt   string          `json:"kdf_salt"`
	KDFParams json.RawMessage `json:"kdf_params"`
}

type loginRequest struct {
	Login    string    `json:"login"`
	Password string    `json:"password"`
	Device   deviceDTO `json:"device"`
}

type loginResponse struct {
	UserID          string          `json:"user_id"`
	VaultID         string          `json:"vault_id"`
	DeviceID        string          `json:"device_id"`
	AccessToken     string          `json:"access_token"`
	RefreshToken    string          `json:"refresh_token"`
	WrappedVaultKey string          `json:"wrapped_vault_key"`
	WrapNonce       string          `json:"wrap_nonce"`
	KDFSalt         string          `json:"kdf_salt"`
	KDFParams       json.RawMessage `json:"kdf_params"`
}

type refreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

type refreshResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
}

type logoutRequest struct {
	RefreshToken string `json:"refresh_token"`
}

type passwordChangeRequest struct {
	OldPassword     string          `json:"old_password"`
	NewPassword     string          `json:"new_password"`
	KDFSalt         string          `json:"kdf_salt"`
	KDFParams       json.RawMessage `json:"kdf_params"`
	WrappedVaultKey string          `json:"wrapped_vault_key"`
	WrapNonce       string          `json:"wrap_nonce"`
}

type meResponse struct {
	User      meUserDTO  `json:"user"`
	Vault     meVaultDTO `json:"vault"`
	ServerRev int64      `json:"server_rev"`
}

type meUserDTO struct {
	ID          string `json:"id"`
	Login       string `json:"login"`
	DisplayName string `json:"display_name"`
}

type meVaultDTO struct {
	ID        string `json:"id"`
	MaxUsers  int    `json:"max_users"`
	UserCount int    `json:"user_count"`
}

type recoveryPreloginRequest struct {
	Login string `json:"login"`
}

type recoveryPreloginResponse struct {
	KDFSalt   string          `json:"kdf_salt"`
	KDFParams json.RawMessage `json:"kdf_params"`
	// WrappedVaultKey and WrapNonce are included here (rather than only
	// after phrase verification) because the wrap is only ever useful to
	// someone who can derive RKEK from the phrase itself - the wrap is
	// opaque ciphertext without it, so serving it pre-verification (like
	// login does post-verification) is safe and lets the client unwrap VK
	// locally in one round trip.
	WrappedVaultKey string `json:"wrapped_vault_key"`
	WrapNonce       string `json:"wrap_nonce"`
}

type recoveryRedeemRequest struct {
	Login           string          `json:"login"`
	Verifier        string          `json:"verifier"`
	NewPassword     string          `json:"new_password"`
	KDFSalt         string          `json:"kdf_salt"`
	KDFParams       json.RawMessage `json:"kdf_params"`
	WrappedVaultKey string          `json:"wrapped_vault_key"`
	WrapNonce       string          `json:"wrap_nonce"`
	Device          deviceDTO       `json:"device"`
}

type recoveryRedeemResponse struct {
	UserID       string `json:"user_id"`
	VaultID      string `json:"vault_id"`
	DeviceID     string `json:"device_id"`
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
}
