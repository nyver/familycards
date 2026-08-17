package membership

import (
	"database/sql"
	"errors"
	"net/http"

	"familycards/server/internal/auth"
	"familycards/server/internal/crypto"
	"familycards/server/internal/httpapi"
	"familycards/server/internal/idgen"
	"familycards/server/internal/model"
	"familycards/server/internal/storage"
)

const maxActiveDevicesPerVault = 10

// Handlers holds the dependencies shared by every membership endpoint.
type Handlers struct {
	db     *storage.DB
	tokens *auth.TokenManager
}

// NewHandlers builds the membership endpoint handlers.
func NewHandlers(db *storage.DB, tokens *auth.TokenManager) *Handlers {
	return &Handlers{db: db, tokens: tokens}
}

// CreateInvite handles POST /v1/invites. Requires bearer auth.
func (h *Handlers) CreateInvite(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id, ok := auth.CurrentIdentity(ctx)
	if !ok {
		httpapi.WriteError(w, httpapi.ErrUnauthorized("not authenticated"))
		return
	}

	var req createInviteRequest
	if err := httpapi.DecodeJSON(r, &req); err != nil {
		httpapi.WriteError(w, err)
		return
	}
	if req.CodeHash == "" || req.WrappedVaultKey == "" || req.WrapNonce == "" || req.KDFSalt == "" || req.TTLHours <= 0 {
		httpapi.WriteError(w, httpapi.ErrBadRequest("missing required fields"))
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
	kdfSalt, err := httpapi.DecodeBinaryField("kdf_salt", req.KDFSalt)
	if err != nil {
		httpapi.WriteError(w, err)
		return
	}

	now := idgen.NowUnix()
	expiresAt := now + int64(req.TTLHours)*3600

	txErr := storage.WithImmediateTx(ctx, h.db.Write, func(tx *sql.Tx) error {
		vault, err := auth.GetVault(ctx, tx, id.VaultID)
		if err != nil {
			return err
		}
		activeUsers, err := auth.CountActiveUsers(ctx, tx, id.VaultID)
		if err != nil {
			return err
		}
		activeInvites, err := CountActiveInvites(ctx, tx, id.VaultID, now)
		if err != nil {
			return err
		}
		if activeUsers+activeInvites >= vault.MaxUsers {
			return httpapi.ErrConflict("member quota reached")
		}

		return CreateInvite(ctx, tx, model.Invite{
			CodeHash:        req.CodeHash,
			VaultID:         id.VaultID,
			WrappedVaultKey: wrappedVK,
			WrapNonce:       wrapNonce,
			KDFSalt:         kdfSalt,
			KDFParams:       string(req.KDFParams),
			CreatedBy:       id.UserID,
			CreatedAt:       now,
			ExpiresAt:       expiresAt,
		})
	})
	if txErr != nil {
		httpapi.WriteError(w, txErr)
		return
	}

	httpapi.WriteJSON(w, http.StatusCreated, createInviteResponse{CodeHash: req.CodeHash, ExpiresAt: expiresAt})
}

// GetInvite handles GET /v1/invites/{code_hash}. Unauthenticated: the
// invitee has no account yet, and knowledge of code_hash (derived from the
// out-of-band code) is the proof of possession.
func (h *Handlers) GetInvite(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	codeHash := r.PathValue("code_hash")

	inv, err := GetInvite(ctx, h.db.Read, codeHash)
	if errors.Is(err, ErrNotFound) {
		httpapi.WriteError(w, httpapi.ErrNotFound("invite not found"))
		return
	}
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to look up invite"))
		return
	}
	if inv.UsedAt != nil || inv.ExpiresAt <= idgen.NowUnix() {
		httpapi.WriteError(w, httpapi.ErrGone("invite no longer valid"))
		return
	}

	httpapi.WriteJSON(w, http.StatusOK, getInviteResponse{
		VaultID:         inv.VaultID,
		WrappedVaultKey: httpapi.EncodeBinaryField(inv.WrappedVaultKey),
		WrapNonce:       httpapi.EncodeBinaryField(inv.WrapNonce),
		KDFSalt:         httpapi.EncodeBinaryField(inv.KDFSalt),
		KDFParams:       []byte(inv.KDFParams),
	})
}

// RedeemInvite handles POST /v1/invites/{code_hash}/redeem.
// Unauthenticated: this is how a new user gets their first credentials.
func (h *Handlers) RedeemInvite(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	codeHash := r.PathValue("code_hash")

	var req redeemInviteRequest
	if err := httpapi.DecodeJSON(r, &req); err != nil {
		httpapi.WriteError(w, err)
		return
	}
	if req.Login == "" || req.Password == "" || req.KDFSalt == "" || req.WrappedVaultKey == "" || req.WrapNonce == "" {
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

	passwordHash, err := crypto.HashPassword(req.Password)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to hash password"))
		return
	}

	refreshRaw, refreshHash, err := auth.NewRefreshToken()
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to generate refresh token"))
		return
	}

	var vaultID, userID, deviceID string
	txErr := storage.WithImmediateTx(ctx, h.db.Write, func(tx *sql.Tx) error {
		inv, err := GetInvite(ctx, tx, codeHash)
		if errors.Is(err, ErrNotFound) {
			return httpapi.ErrNotFound("invite not found")
		}
		if err != nil {
			return err
		}
		now := idgen.NowUnix()
		if inv.UsedAt != nil || inv.ExpiresAt <= now {
			return httpapi.ErrGone("invite no longer valid")
		}

		vault, err := auth.GetVault(ctx, tx, inv.VaultID)
		if err != nil {
			return err
		}
		activeUsers, err := auth.CountActiveUsers(ctx, tx, inv.VaultID)
		if err != nil {
			return err
		}
		if activeUsers >= vault.MaxUsers {
			return httpapi.ErrConflict("member quota reached")
		}

		if _, err := auth.GetUserByLogin(ctx, tx, req.Login); err == nil {
			return httpapi.ErrConflict("login already taken")
		} else if !errors.Is(err, auth.ErrNotFound) {
			return err
		}

		activeDevices, err := auth.CountActiveDevices(ctx, tx, inv.VaultID)
		if err != nil {
			return err
		}
		if activeDevices >= maxActiveDevicesPerVault {
			return httpapi.ErrConflict("device limit reached for this vault")
		}

		// Consume the invite first: the WHERE used_at IS NULL clause makes
		// this the race-safe linearization point. Only the request that
		// wins this UPDATE proceeds to create a user.
		consumed, err := MarkInviteUsed(ctx, tx, codeHash, now)
		if err != nil {
			return err
		}
		if !consumed {
			return httpapi.ErrGone("invite no longer valid")
		}

		vaultID = inv.VaultID
		userID, err = auth.CreateUserInVault(ctx, tx, vaultID, req.Login, req.DisplayName, passwordHash, kdfSalt, string(req.KDFParams), wrappedVK, wrapNonce)
		if err != nil {
			return err
		}
		deviceID, err = auth.CreateDevice(ctx, tx, userID, model.DeviceInput{Name: req.Device.Name, Platform: req.Device.Platform}, refreshHash)
		return err
	})
	if txErr != nil {
		httpapi.WriteError(w, txErr)
		return
	}

	user, err := auth.GetUserByID(ctx, h.db.Read, userID)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to load new account"))
		return
	}

	accessToken, err := h.tokens.IssueAccessToken(userID, vaultID, deviceID)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to issue access token"))
		return
	}

	httpapi.WriteJSON(w, http.StatusOK, redeemInviteResponse{
		UserID:          userID,
		VaultID:         vaultID,
		DeviceID:        deviceID,
		AccessToken:     accessToken,
		RefreshToken:    refreshRaw,
		WrappedVaultKey: httpapi.EncodeBinaryField(user.WrappedVaultKey),
		WrapNonce:       httpapi.EncodeBinaryField(user.WrapNonce),
		KDFSalt:         httpapi.EncodeBinaryField(user.KDFSalt),
		KDFParams:       []byte(user.KDFParams),
	})
}

// DeleteInvite handles DELETE /v1/invites/{code_hash}. Requires bearer
// auth; only removes invites belonging to the caller's vault.
func (h *Handlers) DeleteInvite(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id, ok := auth.CurrentIdentity(ctx)
	if !ok {
		httpapi.WriteError(w, httpapi.ErrUnauthorized("not authenticated"))
		return
	}
	codeHash := r.PathValue("code_hash")

	var deleted bool
	txErr := storage.WithImmediateTx(ctx, h.db.Write, func(tx *sql.Tx) error {
		var err error
		deleted, err = DeleteInvite(ctx, tx, codeHash, id.VaultID)
		return err
	})
	if txErr != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to delete invite"))
		return
	}
	if !deleted {
		httpapi.WriteError(w, httpapi.ErrNotFound("invite not found"))
		return
	}

	httpapi.WriteJSON(w, http.StatusNoContent, nil)
}

// ListMembers handles GET /v1/members. Requires bearer auth.
func (h *Handlers) ListMembers(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id, ok := auth.CurrentIdentity(ctx)
	if !ok {
		httpapi.WriteError(w, httpapi.ErrUnauthorized("not authenticated"))
		return
	}

	users, err := auth.ListMembers(ctx, h.db.Read, id.VaultID)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to list members"))
		return
	}

	out := make([]memberDTO, 0, len(users))
	for _, u := range users {
		devices, err := auth.ListDevicesByUser(ctx, h.db.Read, u.ID)
		if err != nil {
			httpapi.WriteError(w, httpapi.ErrInternal("failed to list devices"))
			return
		}
		deviceDTOs := make([]memberDeviceDTO, 0, len(devices))
		var lastSeen int64
		for _, d := range devices {
			deviceDTOs = append(deviceDTOs, memberDeviceDTO{
				ID: d.ID, Name: d.Name, Platform: d.Platform,
				CreatedAt: d.CreatedAt, LastSeenAt: d.LastSeenAt, Revoked: d.Revoked,
			})
			if d.LastSeenAt > lastSeen {
				lastSeen = d.LastSeenAt
			}
		}
		out = append(out, memberDTO{
			UserID: u.ID, DisplayName: u.DisplayName, Login: u.Login,
			CreatedAt: u.CreatedAt, LastSeenAt: lastSeen, Devices: deviceDTOs,
		})
	}

	httpapi.WriteJSON(w, http.StatusOK, out)
}

// RemoveMember handles DELETE /v1/members/{user_id}. Requires bearer auth.
func (h *Handlers) RemoveMember(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id, ok := auth.CurrentIdentity(ctx)
	if !ok {
		httpapi.WriteError(w, httpapi.ErrUnauthorized("not authenticated"))
		return
	}
	targetID := r.PathValue("user_id")

	txErr := storage.WithImmediateTx(ctx, h.db.Write, func(tx *sql.Tx) error {
		target, err := auth.GetUserByID(ctx, tx, targetID)
		if errors.Is(err, auth.ErrNotFound) {
			return httpapi.ErrNotFound("member not found")
		}
		if err != nil {
			return err
		}
		if target.VaultID != id.VaultID {
			return httpapi.ErrNotFound("member not found")
		}

		if !target.Disabled {
			activeUsers, err := auth.CountActiveUsers(ctx, tx, id.VaultID)
			if err != nil {
				return err
			}
			if activeUsers <= 1 {
				return httpapi.ErrConflict("cannot remove the last active member")
			}
		}

		if err := auth.SetUserDisabled(ctx, tx, targetID, true); err != nil {
			return err
		}
		return auth.RevokeAllUserDevices(ctx, tx, targetID)
	})
	if txErr != nil {
		httpapi.WriteError(w, txErr)
		return
	}

	httpapi.WriteJSON(w, http.StatusNoContent, nil)
}
