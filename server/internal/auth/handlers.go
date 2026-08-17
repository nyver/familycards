package auth

import (
	"context"
	"database/sql"
	"errors"
	"net/http"

	"familycards/server/internal/crypto"
	"familycards/server/internal/httpapi"
	"familycards/server/internal/model"
	"familycards/server/internal/storage"
)

const maxActiveDevicesPerVault = 10

// Handlers holds the dependencies shared by every auth endpoint.
type Handlers struct {
	db             *storage.DB
	tokens         *TokenManager
	bootstrapToken string
	serverSecret   []byte
}

// NewHandlers builds the auth endpoint handlers. bootstrapToken and
// serverSecret come from server configuration (WALLET_BOOTSTRAP_TOKEN and
// WALLET_JWT_SECRET respectively - the JWT secret doubles as the HMAC key
// for deterministic fake prelogin salts, since both are server-only
// secrets and the spec defines no separate variable for the latter).
func NewHandlers(db *storage.DB, tokens *TokenManager, bootstrapToken string, serverSecret []byte) *Handlers {
	return &Handlers{db: db, tokens: tokens, bootstrapToken: bootstrapToken, serverSecret: serverSecret}
}

// Bootstrap handles POST /v1/auth/bootstrap.
func (h *Handlers) Bootstrap(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	presented := r.Header.Get("X-Bootstrap-Token")
	if h.bootstrapToken == "" || !crypto.ConstantTimeEqual([]byte(h.bootstrapToken), []byte(presented)) {
		httpapi.WriteError(w, httpapi.ErrUnauthorized("invalid bootstrap token"))
		return
	}

	var req bootstrapRequest
	if err := httpapi.DecodeJSON(r, &req); err != nil {
		httpapi.WriteError(w, err)
		return
	}
	if req.Login == "" || req.Password == "" || req.KDFSalt == "" || req.WrappedVaultKey == "" || req.WrapNonce == "" {
		httpapi.WriteError(w, httpapi.ErrBadRequest("missing required fields"))
		return
	}
	if req.Recovery.WrappedVaultKey == "" || req.Recovery.WrapNonce == "" || req.Recovery.KDFSalt == "" || req.Recovery.Verifier == "" {
		httpapi.WriteError(w, httpapi.ErrBadRequest("missing recovery fields"))
		return
	}

	kdfSalt, err := httpapi.DecodeBinaryField("kdf_salt", req.KDFSalt)
	if err != nil {
		httpapi.WriteError(w, err)
		return
	}
	wrappedVK, err := httpapi.DecodeBinaryField("wrapped_vault_key", req.WrappedVaultKey)
	if err != nil {
		httpapi.WriteError(w, err)
		return
	}
	wrapNonce, err := httpapi.DecodeBinaryField("wrap_nonce", req.WrapNonce)
	if err != nil {
		httpapi.WriteError(w, err)
		return
	}
	recVK, err := httpapi.DecodeBinaryField("recovery.wrapped_vault_key", req.Recovery.WrappedVaultKey)
	if err != nil {
		httpapi.WriteError(w, err)
		return
	}
	recNonce, err := httpapi.DecodeBinaryField("recovery.wrap_nonce", req.Recovery.WrapNonce)
	if err != nil {
		httpapi.WriteError(w, err)
		return
	}
	recSalt, err := httpapi.DecodeBinaryField("recovery.kdf_salt", req.Recovery.KDFSalt)
	if err != nil {
		httpapi.WriteError(w, err)
		return
	}

	passwordHash, err := crypto.HashPassword(req.Password)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to hash password"))
		return
	}
	verifierHash, err := crypto.HashPassword(req.Recovery.Verifier)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to hash recovery verifier"))
		return
	}

	refreshRaw, refreshHash, err := NewRefreshToken()
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to generate refresh token"))
		return
	}

	var vaultID, userID, deviceID string
	txErr := storage.WithImmediateTx(ctx, h.db.Write, func(tx *sql.Tx) error {
		count, err := CountUsers(ctx, tx)
		if err != nil {
			return err
		}
		if count > 0 {
			return httpapi.ErrConflict("server already bootstrapped")
		}

		vaultID, userID, deviceID, err = Bootstrap(ctx, tx, BootstrapParams{
			Login:           req.Login,
			DisplayName:     req.DisplayName,
			PasswordHash:    passwordHash,
			KDFSalt:         kdfSalt,
			KDFParams:       string(req.KDFParams),
			WrappedVaultKey: wrappedVK,
			WrapNonce:       wrapNonce,
			Recovery: RecoveryInput{
				WrappedVaultKey: recVK,
				WrapNonce:       recNonce,
				KDFSalt:         recSalt,
				KDFParams:       string(req.Recovery.KDFParams),
				VerifierHash:    verifierHash,
			},
			Device:      model.DeviceInput{Name: req.Device.Name, Platform: req.Device.Platform},
			RefreshHash: refreshHash,
		})
		return err
	})
	if txErr != nil {
		httpapi.WriteError(w, txErr)
		return
	}

	accessToken, err := h.tokens.IssueAccessToken(userID, vaultID, deviceID)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to issue access token"))
		return
	}

	httpapi.WriteJSON(w, http.StatusCreated, bootstrapResponse{
		UserID:       userID,
		VaultID:      vaultID,
		DeviceID:     deviceID,
		AccessToken:  accessToken,
		RefreshToken: refreshRaw,
	})
}

// Prelogin handles POST /v1/auth/prelogin.
func (h *Handlers) Prelogin(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req preloginRequest
	if err := httpapi.DecodeJSON(r, &req); err != nil {
		httpapi.WriteError(w, err)
		return
	}
	if req.Login == "" {
		httpapi.WriteError(w, httpapi.ErrBadRequest("login is required"))
		return
	}

	user, err := GetUserByLogin(ctx, h.db.Read, req.Login)
	if err != nil && !errors.Is(err, ErrNotFound) {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to look up account"))
		return
	}

	if err == nil {
		httpapi.WriteJSON(w, http.StatusOK, preloginResponse{
			KDFSalt:   httpapi.EncodeBinaryField(user.KDFSalt),
			KDFParams: []byte(user.KDFParams),
		})
		return
	}

	httpapi.WriteJSON(w, http.StatusOK, preloginResponse{
		KDFSalt:   httpapi.EncodeBinaryField(FakeKDFSalt(h.serverSecret, req.Login)),
		KDFParams: []byte(DefaultKDFParams),
	})
}

// Login handles POST /v1/auth/login.
func (h *Handlers) Login(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req loginRequest
	if err := httpapi.DecodeJSON(r, &req); err != nil {
		httpapi.WriteError(w, err)
		return
	}
	if req.Login == "" || req.Password == "" {
		httpapi.WriteError(w, httpapi.ErrBadRequest("login and password are required"))
		return
	}

	user, err := GetUserByLogin(ctx, h.db.Read, req.Login)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrUnauthorized("invalid login or password"))
		return
	}

	ok, err := crypto.VerifyPassword(req.Password, user.PasswordHash)
	if err != nil || !ok {
		httpapi.WriteError(w, httpapi.ErrUnauthorized("invalid login or password"))
		return
	}
	if user.Disabled {
		httpapi.WriteError(w, httpapi.ErrForbidden("account disabled"))
		return
	}

	refreshRaw, refreshHash, err := NewRefreshToken()
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to generate refresh token"))
		return
	}

	var deviceID string
	txErr := storage.WithImmediateTx(ctx, h.db.Write, func(tx *sql.Tx) error {
		if req.Device.ID != "" {
			if existing, err := FindUserDevice(ctx, tx, user.ID, req.Device.ID); err == nil {
				deviceID = existing.ID
				return UpdateDeviceRefreshHash(ctx, tx, deviceID, refreshHash)
			}
		}

		count, err := CountActiveDevices(ctx, tx, user.VaultID)
		if err != nil {
			return err
		}
		if count >= maxActiveDevicesPerVault {
			return httpapi.ErrConflict("device limit reached for this vault")
		}

		deviceID, err = CreateDevice(ctx, tx, user.ID, model.DeviceInput{ID: req.Device.ID, Name: req.Device.Name, Platform: req.Device.Platform}, refreshHash)
		return err
	})
	if txErr != nil {
		httpapi.WriteError(w, txErr)
		return
	}

	accessToken, err := h.tokens.IssueAccessToken(user.ID, user.VaultID, deviceID)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to issue access token"))
		return
	}

	httpapi.WriteJSON(w, http.StatusOK, loginResponse{
		UserID:          user.ID,
		VaultID:         user.VaultID,
		DeviceID:        deviceID,
		AccessToken:     accessToken,
		RefreshToken:    refreshRaw,
		WrappedVaultKey: httpapi.EncodeBinaryField(user.WrappedVaultKey),
		WrapNonce:       httpapi.EncodeBinaryField(user.WrapNonce),
		KDFSalt:         httpapi.EncodeBinaryField(user.KDFSalt),
		KDFParams:       []byte(user.KDFParams),
	})
}

// Refresh handles POST /v1/auth/refresh.
func (h *Handlers) Refresh(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req refreshRequest
	if err := httpapi.DecodeJSON(r, &req); err != nil {
		httpapi.WriteError(w, err)
		return
	}
	if req.RefreshToken == "" {
		httpapi.WriteError(w, httpapi.ErrBadRequest("refresh_token is required"))
		return
	}
	hash := HashRefreshToken(req.RefreshToken)

	device, err := GetDeviceByRefreshHash(ctx, h.db.Read, hash)
	if err != nil {
		h.handlePossibleReuse(ctx, w, hash)
		return
	}
	if device.Revoked {
		httpapi.WriteError(w, httpapi.ErrUnauthorized("device revoked"))
		return
	}

	newRaw, newHash, err := NewRefreshToken()
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to generate refresh token"))
		return
	}

	txErr := storage.WithImmediateTx(ctx, h.db.Write, func(tx *sql.Tx) error {
		if err := RetireRefreshHash(ctx, tx, device.UserID, hash); err != nil {
			return err
		}
		return UpdateDeviceRefreshHash(ctx, tx, device.ID, newHash)
	})
	if txErr != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to rotate refresh token"))
		return
	}

	user, err := GetUserByID(ctx, h.db.Read, device.UserID)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrUnauthorized("account no longer available"))
		return
	}

	accessToken, err := h.tokens.IssueAccessToken(user.ID, user.VaultID, device.ID)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to issue access token"))
		return
	}

	httpapi.WriteJSON(w, http.StatusOK, refreshResponse{AccessToken: accessToken, RefreshToken: newRaw})
}

// handlePossibleReuse is called when a presented refresh token hash does
// not match any device's current hash. If it matches a retired hash, this
// is a replay of a token that was already rotated away from - treated as
// compromise: every device belonging to that user is revoked.
func (h *Handlers) handlePossibleReuse(ctx context.Context, w http.ResponseWriter, hash string) {
	userID, err := RetiredRefreshTokenUser(ctx, h.db.Read, hash)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrUnauthorized("invalid refresh token"))
		return
	}

	txErr := storage.WithImmediateTx(ctx, h.db.Write, func(tx *sql.Tx) error {
		return RevokeAllUserDevices(ctx, tx, userID)
	})
	if txErr != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to revoke devices"))
		return
	}

	httpapi.WriteError(w, httpapi.ErrUnauthorized("refresh token reuse detected, all devices revoked"))
}

// Logout handles POST /v1/auth/logout. It always returns 204, whether or
// not the token was valid, to avoid revealing session state.
func (h *Handlers) Logout(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req logoutRequest
	if err := httpapi.DecodeJSON(r, &req); err == nil && req.RefreshToken != "" {
		hash := HashRefreshToken(req.RefreshToken)
		if device, err := GetDeviceByRefreshHash(ctx, h.db.Read, hash); err == nil {
			_ = storage.WithImmediateTx(ctx, h.db.Write, func(tx *sql.Tx) error {
				return RevokeDevice(ctx, tx, device.ID)
			})
		}
	}

	httpapi.WriteJSON(w, http.StatusNoContent, nil)
}

// ChangePassword handles POST /v1/auth/password. Requires bearer auth.
func (h *Handlers) ChangePassword(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	id, ok := CurrentIdentity(ctx)
	if !ok {
		httpapi.WriteError(w, httpapi.ErrUnauthorized("not authenticated"))
		return
	}

	var req passwordChangeRequest
	if err := httpapi.DecodeJSON(r, &req); err != nil {
		httpapi.WriteError(w, err)
		return
	}
	if req.OldPassword == "" || req.NewPassword == "" || req.KDFSalt == "" || req.WrappedVaultKey == "" || req.WrapNonce == "" {
		httpapi.WriteError(w, httpapi.ErrBadRequest("missing required fields"))
		return
	}

	user, err := GetUserByID(ctx, h.db.Read, id.UserID)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrUnauthorized("account no longer available"))
		return
	}

	ok2, err := crypto.VerifyPassword(req.OldPassword, user.PasswordHash)
	if err != nil || !ok2 {
		httpapi.WriteError(w, httpapi.ErrUnauthorized("invalid current password"))
		return
	}

	kdfSalt, err := httpapi.DecodeBinaryField("kdf_salt", req.KDFSalt)
	if err != nil {
		httpapi.WriteError(w, err)
		return
	}
	wrappedVK, err := httpapi.DecodeBinaryField("wrapped_vault_key", req.WrappedVaultKey)
	if err != nil {
		httpapi.WriteError(w, err)
		return
	}
	wrapNonce, err := httpapi.DecodeBinaryField("wrap_nonce", req.WrapNonce)
	if err != nil {
		httpapi.WriteError(w, err)
		return
	}

	newHash, err := crypto.HashPassword(req.NewPassword)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to hash password"))
		return
	}

	txErr := storage.WithImmediateTx(ctx, h.db.Write, func(tx *sql.Tx) error {
		return UpdateUserPasswordAndWrap(ctx, tx, user.ID, newHash, kdfSalt, string(req.KDFParams), wrappedVK, wrapNonce)
	})
	if txErr != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to update password"))
		return
	}

	httpapi.WriteJSON(w, http.StatusNoContent, nil)
}

// Me handles GET /v1/me. Requires bearer auth.
func (h *Handlers) Me(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	id, ok := CurrentIdentity(ctx)
	if !ok {
		httpapi.WriteError(w, httpapi.ErrUnauthorized("not authenticated"))
		return
	}

	user, err := GetUserByID(ctx, h.db.Read, id.UserID)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrUnauthorized("account no longer available"))
		return
	}
	vault, err := GetVault(ctx, h.db.Read, id.VaultID)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to load vault"))
		return
	}
	userCount, err := CountActiveUsers(ctx, h.db.Read, id.VaultID)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to count members"))
		return
	}

	httpapi.WriteJSON(w, http.StatusOK, meResponse{
		User:      meUserDTO{ID: user.ID, Login: user.Login, DisplayName: user.DisplayName},
		Vault:     meVaultDTO{ID: vault.ID, MaxUsers: vault.MaxUsers, UserCount: userCount},
		ServerRev: vault.LastRev,
	})
}

// RecoveryPrelogin handles POST /v1/auth/recovery/prelogin. Mirrors
// Prelogin's indistinguishability property: an unknown login gets a
// deterministic fake salt rather than an error, so the response shape
// never reveals whether the account exists.
func (h *Handlers) RecoveryPrelogin(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req recoveryPreloginRequest
	if err := httpapi.DecodeJSON(r, &req); err != nil {
		httpapi.WriteError(w, err)
		return
	}
	if req.Login == "" {
		httpapi.WriteError(w, httpapi.ErrBadRequest("login is required"))
		return
	}

	rk, err := GetRecoveryKeyByLogin(ctx, h.db.Read, req.Login)
	if err != nil && !errors.Is(err, ErrNotFound) {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to look up account"))
		return
	}

	if err == nil {
		httpapi.WriteJSON(w, http.StatusOK, recoveryPreloginResponse{
			KDFSalt:         httpapi.EncodeBinaryField(rk.KDFSalt),
			KDFParams:       []byte(rk.KDFParams),
			WrappedVaultKey: httpapi.EncodeBinaryField(rk.WrappedVaultKey),
			WrapNonce:       httpapi.EncodeBinaryField(rk.WrapNonce),
		})
		return
	}

	httpapi.WriteJSON(w, http.StatusOK, recoveryPreloginResponse{
		KDFSalt:         httpapi.EncodeBinaryField(FakeRecoveryKDFSalt(h.serverSecret, req.Login)),
		KDFParams:       []byte(DefaultKDFParams),
		WrappedVaultKey: httpapi.EncodeBinaryField(FakeRecoveryWrappedVaultKey(h.serverSecret, req.Login)),
		WrapNonce:       httpapi.EncodeBinaryField(FakeRecoveryWrapNonce(h.serverSecret, req.Login)),
	})
}

// RecoveryRedeem handles POST /v1/auth/recovery/redeem. Authenticates the
// caller by verifying the recovery phrase (via the stored verifier_hash)
// rather than a password - the client has already used the phrase to
// unwrap VK locally by the time it calls this, and here re-wraps VK under
// a brand new password, which this endpoint persists alongside a new
// password_hash. Effectively a full password reset, gated on phrase
// knowledge instead of the old password.
func (h *Handlers) RecoveryRedeem(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req recoveryRedeemRequest
	if err := httpapi.DecodeJSON(r, &req); err != nil {
		httpapi.WriteError(w, err)
		return
	}
	if req.Login == "" || req.Verifier == "" || req.NewPassword == "" || req.KDFSalt == "" || req.WrappedVaultKey == "" || req.WrapNonce == "" {
		httpapi.WriteError(w, httpapi.ErrBadRequest("missing required fields"))
		return
	}

	kdfSalt, err := httpapi.DecodeBinaryField("kdf_salt", req.KDFSalt)
	if err != nil {
		httpapi.WriteError(w, err)
		return
	}
	wrappedVK, err := httpapi.DecodeBinaryField("wrapped_vault_key", req.WrappedVaultKey)
	if err != nil {
		httpapi.WriteError(w, err)
		return
	}
	wrapNonce, err := httpapi.DecodeBinaryField("wrap_nonce", req.WrapNonce)
	if err != nil {
		httpapi.WriteError(w, err)
		return
	}

	user, err := GetUserByLogin(ctx, h.db.Read, req.Login)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrUnauthorized("invalid login or recovery phrase"))
		return
	}
	rk, err := GetRecoveryKey(ctx, h.db.Read, user.VaultID)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrUnauthorized("invalid login or recovery phrase"))
		return
	}

	ok, err := crypto.VerifyPassword(req.Verifier, rk.VerifierHash)
	if err != nil || !ok {
		httpapi.WriteError(w, httpapi.ErrUnauthorized("invalid login or recovery phrase"))
		return
	}

	newPasswordHash, err := crypto.HashPassword(req.NewPassword)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to hash password"))
		return
	}
	refreshRaw, refreshHash, err := NewRefreshToken()
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to generate refresh token"))
		return
	}

	var deviceID string
	txErr := storage.WithImmediateTx(ctx, h.db.Write, func(tx *sql.Tx) error {
		if err := UpdateUserPasswordAndWrap(ctx, tx, user.ID, newPasswordHash, kdfSalt, string(req.KDFParams), wrappedVK, wrapNonce); err != nil {
			return err
		}
		// A successful recovery is a strong signal the previous password
		// (and any device holding it) should no longer be trusted.
		if err := RevokeAllUserDevices(ctx, tx, user.ID); err != nil {
			return err
		}
		var err error
		deviceID, err = CreateDevice(ctx, tx, user.ID, model.DeviceInput{Name: req.Device.Name, Platform: req.Device.Platform}, refreshHash)
		return err
	})
	if txErr != nil {
		httpapi.WriteError(w, txErr)
		return
	}

	accessToken, err := h.tokens.IssueAccessToken(user.ID, user.VaultID, deviceID)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to issue access token"))
		return
	}

	httpapi.WriteJSON(w, http.StatusOK, recoveryRedeemResponse{
		UserID:       user.ID,
		VaultID:      user.VaultID,
		DeviceID:     deviceID,
		AccessToken:  accessToken,
		RefreshToken: refreshRaw,
	})
}
