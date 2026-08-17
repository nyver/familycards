package blobs

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"errors"
	"io"
	"net/http"

	"familycards/server/internal/auth"
	"familycards/server/internal/httpapi"
	"familycards/server/internal/idgen"
	"familycards/server/internal/storage"
)

const maxBlobBytes = 8 << 20 // 8 MiB, enforced again here as a defense in depth alongside httpapi.LimitBody

// Handlers holds the dependencies shared by every blob endpoint.
type Handlers struct {
	db    *storage.DB
	store *Store
}

// NewHandlers builds the blob endpoint handlers.
func NewHandlers(db *storage.DB, store *Store) *Handlers {
	return &Handlers{db: db, store: store}
}

type uploadResponse struct {
	BlobID string `json:"blob_id"`
	Size   int64  `json:"size"`
}

// Upload handles POST /v1/blobs. Requires bearer auth. Body is
// application/octet-stream: nonce || ciphertext. The X-Blob-Id header must
// carry the hex sha256 of the exact bytes received.
func (h *Handlers) Upload(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id, ok := auth.CurrentIdentity(ctx)
	if !ok {
		httpapi.WriteError(w, httpapi.ErrUnauthorized("not authenticated"))
		return
	}

	claimedID := r.Header.Get("X-Blob-Id")
	if claimedID == "" {
		httpapi.WriteError(w, httpapi.ErrBadRequest("X-Blob-Id header is required"))
		return
	}

	body, err := io.ReadAll(io.LimitReader(r.Body, maxBlobBytes+1))
	if err != nil {
		var maxBytesErr *http.MaxBytesError
		if errors.As(err, &maxBytesErr) {
			httpapi.WriteError(w, httpapi.ErrTooLarge("blob exceeds 8 MiB"))
			return
		}
		httpapi.WriteError(w, httpapi.ErrBadRequest("failed to read request body"))
		return
	}
	if len(body) > maxBlobBytes {
		httpapi.WriteError(w, httpapi.ErrTooLarge("blob exceeds 8 MiB"))
		return
	}

	sum := sha256.Sum256(body)
	actualID := hex.EncodeToString(sum[:])
	if actualID != claimedID {
		httpapi.WriteError(w, httpapi.ErrBadRequest("X-Blob-Id does not match sha256 of the request body"))
		return
	}

	if !h.store.Exists(id.VaultID, actualID) {
		if err := h.store.Write(id.VaultID, actualID, body); err != nil {
			httpapi.WriteError(w, httpapi.ErrInternal("failed to store blob"))
			return
		}
	}

	var created bool
	txErr := storage.WithImmediateTx(ctx, h.db.Write, func(tx *sql.Tx) error {
		var err error
		created, err = InsertIfAbsent(ctx, tx, id.VaultID, actualID, int64(len(body)), idgen.NowUnix())
		return err
	})
	if txErr != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to record blob metadata"))
		return
	}

	status := http.StatusOK
	if created {
		status = http.StatusCreated
	}
	httpapi.WriteJSON(w, status, uploadResponse{BlobID: actualID, Size: int64(len(body))})
}

// Get handles GET /v1/blobs/{blob_id}. Requires bearer auth. Returns 404
// for a blob that does not exist or belongs to a different vault.
func (h *Handlers) Get(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id, ok := auth.CurrentIdentity(ctx)
	if !ok {
		httpapi.WriteError(w, httpapi.ErrUnauthorized("not authenticated"))
		return
	}
	blobID := r.PathValue("blob_id")

	meta, err := GetMeta(ctx, h.db.Read, id.VaultID, blobID)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("failed to look up blob"))
		return
	}
	if meta == nil {
		httpapi.WriteError(w, httpapi.ErrNotFound("blob not found"))
		return
	}

	data, err := h.store.Read(id.VaultID, blobID)
	if err != nil {
		httpapi.WriteError(w, httpapi.ErrInternal("blob metadata exists but file is missing"))
		return
	}

	w.Header().Set("Content-Type", "application/octet-stream")
	w.WriteHeader(http.StatusOK)
	w.Write(data)
}
