package sync

import (
	"database/sql"
	"errors"
	"net/http"
	"strconv"

	"familycards/server/internal/auth"
	"familycards/server/internal/httpapi"
	"familycards/server/internal/storage"
)

const (
	defaultChangesLimit = 200
	maxChangesLimit     = 500
	maxPushBatchSize    = 100
)

// Handlers holds the dependencies shared by every sync endpoint.
type Handlers struct {
	db *storage.DB
}

// NewHandlers builds the sync endpoint handlers.
func NewHandlers(db *storage.DB) *Handlers {
	return &Handlers{db: db}
}

// GetChanges handles GET /v1/sync/changes. Requires bearer auth.
func (h *Handlers) GetChanges(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id, ok := auth.CurrentIdentity(ctx)
	if !ok {
		httpapi.WriteError(w, httpapi.ErrUnauthorized("not authenticated"))
		return
	}

	since, err := parseInt64Query(r, "since", 0)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrBadRequest("invalid since"))
		return
	}
	limit, err := parseInt64Query(r, "limit", defaultChangesLimit)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrBadRequest("invalid limit"))
		return
	}
	if limit <= 0 || limit > maxChangesLimit {
		limit = maxChangesLimit
	}

	items, err := ListChanges(ctx, h.db.Read, id.VaultID, since, int(limit))
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to list changes"))
		return
	}
	serverRev, err := GetVaultRev(ctx, h.db.Read, id.VaultID)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to read vault revision"))
		return
	}

	nextSince := since
	if len(items) > 0 {
		nextSince = items[len(items)-1].Rev
	}

	httpapi.WriteJSON(w, http.StatusOK, changesResponse{
		ServerRev: serverRev,
		NextSince: nextSince,
		HasMore:   nextSince < serverRev,
		Items:     toItemDTOs(items),
	})
}

// Push handles POST /v1/sync/push. Requires bearer auth.
func (h *Handlers) Push(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id, ok := auth.CurrentIdentity(ctx)
	if !ok {
		httpapi.WriteError(w, httpapi.ErrUnauthorized("not authenticated"))
		return
	}

	var req pushRequest
	if err := httpapi.DecodeJSON(r, &req); err != nil {
		httpapi.WriteError(w, err)
		return
	}
	if req.DeviceID != id.DeviceID {
		httpapi.WriteError(w, httpapi.ErrBadRequest("device_id does not match authenticated device"))
		return
	}
	if len(req.Items) > maxPushBatchSize {
		httpapi.WriteError(w, httpapi.ErrBadRequest("batch exceeds maximum of 100 items"))
		return
	}

	// Decode and validate every item before touching the database, so a
	// malformed item anywhere in the batch fails the whole request with
	// nothing written and last_rev untouched - full atomicity, not just
	// transactional atomicity.
	decoded := make([]Item, len(req.Items))
	allBlobRefs := make(map[string]struct{})
	for i, dto := range req.Items {
		it, err := decodePushItem(id.VaultID, req.DeviceID, dto)
		if err != nil {
			httpapi.WriteError(w, err)
			return
		}
		decoded[i] = it
		for _, b := range it.BlobRefs {
			allBlobRefs[b] = struct{}{}
		}
	}
	blobRefList := make([]string, 0, len(allBlobRefs))
	for b := range allBlobRefs {
		blobRefList = append(blobRefList, b)
	}

	var accepted []acceptedDTO
	var conflicts []itemDTO
	var serverRev int64

	txErr := storage.WithImmediateTx(ctx, h.db.Write, func(tx *sql.Tx) error {
		missing, err := MissingBlobRefs(ctx, tx, id.VaultID, blobRefList)
		if err != nil {
			return err
		}
		if len(missing) > 0 {
			return httpapi.ErrConflict("references blobs that were not uploaded")
		}

		for _, incoming := range decoded {
			cur, err := GetItem(ctx, tx, id.VaultID, incoming.ItemID)
			currentItem := CurrentItem{}
			if err == nil {
				currentItem = CurrentItem{Exists: true, Rev: cur.Rev, UpdatedAt: cur.UpdatedAt, DeviceID: cur.DeviceID}
			} else if !errors.Is(err, ErrNotFound) {
				return err
			}

			// incoming.Rev carries base_rev in this local representation
			// (see decodePushItem).
			accept := Resolve(currentItem, Incoming{BaseRev: incoming.Rev, UpdatedAt: incoming.UpdatedAt, DeviceID: incoming.DeviceID})

			if !accept {
				if err == nil {
					conflicts = append(conflicts, itemDTOFrom(*cur))
				} else {
					conflicts = append(conflicts, goneConflictDTO(incoming.ItemID, incoming.Kind))
				}
				continue
			}

			newRev, err := IncrementVaultRev(ctx, tx, id.VaultID)
			if err != nil {
				return err
			}
			toStore := incoming
			toStore.Rev = newRev
			if err := UpsertItem(ctx, tx, toStore); err != nil {
				return err
			}
			if err := MarkBlobsReferenced(ctx, tx, id.VaultID, toStore.BlobRefs); err != nil {
				return err
			}
			accepted = append(accepted, acceptedDTO{ItemID: toStore.ItemID, Rev: newRev})
		}

		var err2 error
		serverRev, err2 = GetVaultRev(ctx, tx, id.VaultID)
		return err2
	})
	if txErr != nil {
		httpapi.WriteError(w, txErr)
		return
	}

	if accepted == nil {
		accepted = []acceptedDTO{}
	}
	if conflicts == nil {
		conflicts = []itemDTO{}
	}
	httpapi.WriteJSON(w, http.StatusOK, pushResponse{ServerRev: serverRev, Accepted: accepted, Conflicts: conflicts})
}

// decodePushItem converts the wire DTO into the internal Item shape. The
// returned Item's Rev field temporarily carries base_rev (the field is
// repurposed for the actual assigned revision once accepted) to avoid a
// third parallel struct just for this one call site.
func decodePushItem(vaultID, deviceID string, dto pushItemDTO) (Item, error) {
	nonce, err := decodeOptionalBinary("nonce", dto.Nonce)
	if err != nil {
		return Item{}, err
	}
	ciphertext, err := decodeOptionalBinary("ciphertext", dto.Ciphertext)
	if err != nil {
		return Item{}, err
	}
	if dto.ItemID == "" || dto.Kind == "" {
		return Item{}, httpapi.ErrBadRequest("item_id and kind are required")
	}
	if !dto.Deleted && (nonce == nil || ciphertext == nil) {
		return Item{}, httpapi.ErrBadRequest("nonce and ciphertext are required for non-deleted items")
	}

	blobRefs := dto.BlobRefs
	if blobRefs == nil {
		blobRefs = []string{}
	}

	return Item{
		VaultID:    vaultID,
		ItemID:     dto.ItemID,
		Kind:       dto.Kind,
		Rev:        dto.BaseRev, // repurposed, see doc comment above
		UpdatedAt:  dto.UpdatedAt,
		Deleted:    dto.Deleted,
		DeviceID:   deviceID,
		Nonce:      nonce,
		Ciphertext: ciphertext,
		BlobRefs:   blobRefs,
	}, nil
}

func decodeOptionalBinary(field string, v *string) ([]byte, error) {
	if v == nil {
		return nil, nil
	}
	b, err := httpapi.DecodeBinaryField(field, *v)
	if err != nil {
		return nil, err
	}
	return b, nil
}

func toItemDTOs(items []Item) []itemDTO {
	out := make([]itemDTO, len(items))
	for i, it := range items {
		out[i] = itemDTOFrom(it)
	}
	return out
}

func itemDTOFrom(it Item) itemDTO {
	dto := itemDTO{
		ItemID:    it.ItemID,
		Kind:      it.Kind,
		Rev:       it.Rev,
		UpdatedAt: it.UpdatedAt,
		Deleted:   it.Deleted,
		DeviceID:  it.DeviceID,
		BlobRefs:  it.BlobRefs,
	}
	if dto.BlobRefs == nil {
		dto.BlobRefs = []string{}
	}
	if it.Nonce != nil {
		s := httpapi.EncodeBinaryField(it.Nonce)
		dto.Nonce = &s
	}
	if it.Ciphertext != nil {
		s := httpapi.EncodeBinaryField(it.Ciphertext)
		dto.Ciphertext = &s
	}
	return dto
}

// goneConflictDTO represents a conflict against an item the server has no
// record of at all (base_rev pointed at a revision that no longer exists).
// Reporting it as an already-deleted tombstone lets the client converge by
// simply dropping its local copy, same as it would for a normal deletion.
func goneConflictDTO(itemID, kind string) itemDTO {
	return itemDTO{ItemID: itemID, Kind: kind, Rev: 0, UpdatedAt: 0, Deleted: true, DeviceID: "", BlobRefs: []string{}}
}

func parseInt64Query(r *http.Request, key string, def int64) (int64, error) {
	raw := r.URL.Query().Get(key)
	if raw == "" {
		return def, nil
	}
	return strconv.ParseInt(raw, 10, 64)
}
