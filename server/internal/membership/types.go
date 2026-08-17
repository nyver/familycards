package membership

import "encoding/json"

type deviceDTO struct {
	ID       string `json:"id,omitempty"`
	Name     string `json:"name"`
	Platform string `json:"platform"`
}

type createInviteRequest struct {
	CodeHash        string          `json:"code_hash"`
	WrappedVaultKey string          `json:"wrapped_vault_key"`
	WrapNonce       string          `json:"wrap_nonce"`
	KDFSalt         string          `json:"kdf_salt"`
	KDFParams       json.RawMessage `json:"kdf_params"`
	TTLHours        int             `json:"ttl_hours"`
}

type createInviteResponse struct {
	CodeHash  string `json:"code_hash"`
	ExpiresAt int64  `json:"expires_at"`
}

type getInviteResponse struct {
	VaultID         string          `json:"vault_id"`
	WrappedVaultKey string          `json:"wrapped_vault_key"`
	WrapNonce       string          `json:"wrap_nonce"`
	KDFSalt         string          `json:"kdf_salt"`
	KDFParams       json.RawMessage `json:"kdf_params"`
}

type redeemInviteRequest struct {
	Login           string          `json:"login"`
	DisplayName     string          `json:"display_name"`
	Password        string          `json:"password"`
	KDFSalt         string          `json:"kdf_salt"`
	KDFParams       json.RawMessage `json:"kdf_params"`
	WrappedVaultKey string          `json:"wrapped_vault_key"`
	WrapNonce       string          `json:"wrap_nonce"`
	Device          deviceDTO       `json:"device"`
}

type redeemInviteResponse struct {
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

type memberDeviceDTO struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	Platform   string `json:"platform"`
	CreatedAt  int64  `json:"created_at"`
	LastSeenAt int64  `json:"last_seen_at"`
	Revoked    bool   `json:"revoked"`
}

type memberDTO struct {
	UserID      string            `json:"user_id"`
	DisplayName string            `json:"display_name"`
	Login       string            `json:"login"`
	CreatedAt   int64             `json:"created_at"`
	LastSeenAt  int64             `json:"last_seen_at"`
	Devices     []memberDeviceDTO `json:"devices"`
}
