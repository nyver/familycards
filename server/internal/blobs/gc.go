package blobs

import (
	"context"
	"database/sql"
	"fmt"
	"log/slog"

	"familycards/server/internal/logging"
	"familycards/server/internal/storage"
)

const (
	unreferencedGraceSeconds = 24 * 60 * 60
	orphanGraceSeconds       = 7 * 24 * 60 * 60
)

// RunGC performs one garbage collection pass: it removes blobs that were
// uploaded but never confirmed by a push within 24 hours, and blobs that
// were once referenced but no longer are (their owning item was deleted or
// edited to drop them) for at least 7 days. It returns the number of blobs
// removed in each category.
func RunGC(ctx context.Context, db *storage.DB, store *Store, nowUnix int64) (unreferencedRemoved, orphanedRemoved int, err error) {
	unreferencedRemoved, err = collectUnreferenced(ctx, db, store, nowUnix)
	if err != nil {
		return unreferencedRemoved, 0, fmt.Errorf("blobs: gc unreferenced: %w", err)
	}

	orphanedRemoved, err = collectOrphaned(ctx, db, store, nowUnix)
	if err != nil {
		return unreferencedRemoved, orphanedRemoved, fmt.Errorf("blobs: gc orphaned: %w", err)
	}

	return unreferencedRemoved, orphanedRemoved, nil
}

// collectUnreferenced lists never-confirmed blobs older than the grace
// period, then for each one atomically re-checks referenced=0 and deletes
// inside the same transaction - a push that confirms the blob between the
// list and this delete loses the race cleanly (the delete simply becomes a
// no-op for that blob) rather than removing a blob a client just started
// relying on.
func collectUnreferenced(ctx context.Context, db *storage.DB, store *Store, nowUnix int64) (int, error) {
	candidates, err := ListUnreferencedOlderThan(ctx, db.Read, nowUnix-unreferencedGraceSeconds)
	if err != nil {
		return 0, err
	}

	removed := 0
	for _, m := range candidates {
		var deleted bool
		err := storage.WithImmediateTx(ctx, db.Write, func(tx *sql.Tx) error {
			var err error
			deleted, err = DeleteMetaIfUnreferenced(ctx, tx, m.VaultID, m.BlobID)
			return err
		})
		if err != nil {
			return removed, err
		}
		if !deleted {
			continue
		}
		removeFileBestEffort(store, m)
		removed++
	}
	return removed, nil
}

// collectOrphaned lists once-referenced blobs older than the grace period
// with no live item pointing at them (as of the listing query), then for
// each candidate re-checks liveness one more time inside the delete
// transaction. This closes the window where a push re-references a
// previously orphaned blob (legal: MissingBlobRefs only checks that the
// blob was ever uploaded, not that it is still referenced) between the
// list and the delete.
func collectOrphaned(ctx context.Context, db *storage.DB, store *Store, nowUnix int64) (int, error) {
	candidates, err := ListReferencedOlderThan(ctx, db.Read, nowUnix-orphanGraceSeconds)
	if err != nil {
		return 0, err
	}
	if len(candidates) == 0 {
		return 0, nil
	}

	// Group by vault purely to batch the first-pass liveness check; the
	// authoritative check happens per-candidate inside its delete
	// transaction below.
	byVault := make(map[string][]Meta)
	for _, c := range candidates {
		byVault[c.VaultID] = append(byVault[c.VaultID], c)
	}

	removed := 0
	for vaultID, metas := range byVault {
		live, err := LiveBlobRefs(ctx, db.Read, vaultID)
		if err != nil {
			return removed, err
		}
		for _, m := range metas {
			if live[m.BlobID] {
				continue
			}

			var deleted bool
			txErr := storage.WithImmediateTx(ctx, db.Write, func(tx *sql.Tx) error {
				stillLive, err := IsBlobLive(ctx, tx, vaultID, m.BlobID)
				if err != nil {
					return err
				}
				if stillLive {
					return nil
				}
				// The referenced flag itself never reverts to 0 once set,
				// so the liveness recheck above is the only guard needed
				// here; delete unconditionally now that we've confirmed,
				// inside this transaction, that no live item points at it.
				if err := DeleteMeta(ctx, tx, vaultID, m.BlobID); err != nil {
					return err
				}
				deleted = true
				return nil
			})
			if txErr != nil {
				return removed, txErr
			}
			if !deleted {
				continue
			}
			removeFileBestEffort(store, m)
			removed++
		}
	}
	return removed, nil
}

// removeFileBestEffort deletes a blob's file after its metadata row is
// already gone. File deletion is best-effort and idempotent (Store.Delete
// treats a missing file as success) - GC must survive a file that was
// already removed by hand or by a previous, interrupted pass.
func removeFileBestEffort(store *Store, m Meta) {
	if err := store.Delete(m.VaultID, m.BlobID); err != nil {
		slog.Error("blobs: failed to delete file during gc", "blob_id_prefix", logging.BlobIDPrefix(m.BlobID), "error", err)
	}
}
