package blobs_test

import (
	"bytes"
	"context"
	"net/http"
	"os"
	"testing"
	"time"

	"familycards/server/internal/blobs"
	"familycards/server/internal/storage"
)

func insertBlobRow(t *testing.T, db *storage.DB, vaultID, blobID string, referenced bool, createdAt int64) {
	t.Helper()
	ref := 0
	if referenced {
		ref = 1
	}
	// Ensure the parent vault row exists to satisfy any future FK checks
	// and to keep the fixture realistic.
	_, _ = db.Write.Exec(`INSERT OR IGNORE INTO vaults (id, created_at, last_rev, max_users) VALUES (?, ?, 0, 5)`, vaultID, createdAt)
	if _, err := db.Write.Exec(
		`INSERT INTO blobs (vault_id, blob_id, size, created_at, referenced) VALUES (?, ?, ?, ?, ?)`,
		vaultID, blobID, 4, createdAt, ref,
	); err != nil {
		t.Fatalf("insert blob row: %v", err)
	}
}

func insertLiveItemReferencing(t *testing.T, db *storage.DB, vaultID, itemID, blobID string) {
	t.Helper()
	if _, err := db.Write.Exec(
		`INSERT INTO items (vault_id, item_id, kind, rev, updated_at, deleted, device_id, nonce, ciphertext, blob_refs)
		 VALUES (?, ?, 'card', 1, 0, 0, 'dev-a', X'00', X'00', ?)`,
		vaultID, itemID, `["`+blobID+`"]`,
	); err != nil {
		t.Fatalf("insert live item: %v", err)
	}
}

type uploadResp struct {
	BlobID string `json:"blob_id"`
	Size   int64  `json:"size"`
}

// Scenario 8: idempotent re-upload does not rewrite the file; a mismatched
// X-Blob-Id is rejected.
func TestAcceptance_IdempotentUpload(t *testing.T) {
	srv, _, store := newTestServer(t)
	a := bootstrap(t, srv.URL, "alice")
	data := []byte("a photo of a loyalty card, pretend this is encrypted bytes")

	first := uploadBlob(t, srv.URL, a.AccessToken, data)
	if first.StatusCode != http.StatusCreated {
		t.Fatalf("first upload status = %d, want 201", first.StatusCode)
	}
	var firstResp uploadResp
	decodeJSON(t, first, &firstResp)

	path := store.Path(a.VaultID, firstResp.BlobID)
	infoBefore, err := os.Stat(path)
	if err != nil {
		t.Fatalf("stat blob file: %v", err)
	}

	time.Sleep(20 * time.Millisecond) // ensure mtime would visibly differ if rewritten

	second := uploadBlob(t, srv.URL, a.AccessToken, data)
	if second.StatusCode != http.StatusOK {
		t.Fatalf("second upload status = %d, want 200 (idempotent)", second.StatusCode)
	}
	var secondResp uploadResp
	decodeJSON(t, second, &secondResp)
	if secondResp.BlobID != firstResp.BlobID || secondResp.Size != firstResp.Size {
		t.Errorf("second upload response = %+v, want same blob_id/size as first %+v", secondResp, firstResp)
	}

	infoAfter, err := os.Stat(path)
	if err != nil {
		t.Fatalf("stat blob file after re-upload: %v", err)
	}
	if !infoBefore.ModTime().Equal(infoAfter.ModTime()) {
		t.Errorf("file mtime changed on idempotent re-upload: before=%v after=%v", infoBefore.ModTime(), infoAfter.ModTime())
	}
}

func TestAcceptance_BlobIDMismatchRejected(t *testing.T) {
	srv, _, _ := newTestServer(t)
	a := bootstrap(t, srv.URL, "alice")

	data := []byte("real content")
	req, _ := http.NewRequest(http.MethodPost, srv.URL+"/v1/blobs", bytes.NewReader(data))
	req.Header.Set("Authorization", "Bearer "+a.AccessToken)
	req.Header.Set("X-Blob-Id", "0000000000000000000000000000000000000000000000000000000000000000")
	resp, err := testHTTPClient().Do(req)
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("mismatched X-Blob-Id status = %d, want 400", resp.StatusCode)
	}
}

func TestAcceptance_UploadAndRetrieve(t *testing.T) {
	srv, _, _ := newTestServer(t)
	a := bootstrap(t, srv.URL, "alice")
	data := []byte("card photo bytes")

	up := uploadBlob(t, srv.URL, a.AccessToken, data)
	var ur uploadResp
	decodeJSON(t, up, &ur)

	getResp := doJSON(t, http.MethodGet, srv.URL+"/v1/blobs/"+ur.BlobID, authHeader(a.AccessToken), nil)
	if getResp.StatusCode != http.StatusOK {
		t.Fatalf("GET blob status = %d, want 200", getResp.StatusCode)
	}
	defer getResp.Body.Close()
	got := make([]byte, len(data))
	n, _ := getResp.Body.Read(got)
	if n != len(data) || string(got) != string(data) {
		t.Errorf("retrieved blob content mismatch: got %q, want %q", got[:n], data)
	}
}

// The HTTP API only ever exposes one vault per running server (bootstrap
// refuses once any user exists), so cross-vault isolation for GET
// /v1/blobs/{blob_id} - which matters for a deployment that somehow ends
// up with two vault rows, or simply as a defense-in-depth guarantee of the
// query itself - is exercised directly against the repository, which is
// exactly what the HTTP handler delegates to.
func TestAcceptance_BlobMetaIsolatedPerVault(t *testing.T) {
	_, db, store := newTestServer(t)
	ctx := context.Background()

	if err := store.Write("vault-a", "shared-id", []byte("a's bytes")); err != nil {
		t.Fatalf("Write: %v", err)
	}
	insertBlobRow(t, db, "vault-a", "shared-id", true, time.Now().Unix())
	insertBlobRow(t, db, "vault-b", "shared-id", true, time.Now().Unix())

	metaA, err := blobs.GetMeta(ctx, db.Read, "vault-a", "shared-id")
	if err != nil {
		t.Fatalf("GetMeta(vault-a): %v", err)
	}
	if metaA == nil {
		t.Fatal("expected metadata for vault-a's own blob")
	}

	metaWrongVault, err := blobs.GetMeta(ctx, db.Read, "vault-c", "shared-id")
	if err != nil {
		t.Fatalf("GetMeta(vault-c): %v", err)
	}
	if metaWrongVault != nil {
		t.Error("GetMeta should not find a blob belonging to a different vault")
	}
}

func TestAcceptance_OversizedBlobRejected(t *testing.T) {
	srv, _, _ := newTestServer(t)
	a := bootstrap(t, srv.URL, "alice")

	oversized := bytes.Repeat([]byte("a"), (8<<20)+1)
	req, _ := http.NewRequest(http.MethodPost, srv.URL+"/v1/blobs", bytes.NewReader(oversized))
	req.Header.Set("Authorization", "Bearer "+a.AccessToken)
	req.Header.Set("X-Blob-Id", sha256Hex(oversized))
	resp, err := testHTTPClient().Do(req)
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusRequestEntityTooLarge {
		t.Errorf("oversized upload status = %d, want 413", resp.StatusCode)
	}
}

// Scenario 12: an unreferenced blob older than 24h is removed; a
// referenced one is not.
func TestAcceptance_GC_UnreferencedRemovedReferencedKept(t *testing.T) {
	_, db, store := newTestServer(t)
	ctx := context.Background()

	if err := store.Write("vault-x", "old-unreferenced", []byte("data")); err != nil {
		t.Fatalf("Write: %v", err)
	}
	insertBlobRow(t, db, "vault-x", "old-unreferenced", false, time.Now().Add(-48*time.Hour).Unix())

	if err := store.Write("vault-x", "referenced-blob", []byte("data")); err != nil {
		t.Fatalf("Write: %v", err)
	}
	insertBlobRow(t, db, "vault-x", "referenced-blob", true, time.Now().Add(-48*time.Hour).Unix())
	insertLiveItemReferencing(t, db, "vault-x", "item-1", "referenced-blob")

	unreferencedRemoved, orphanedRemoved, err := blobs.RunGC(ctx, db, store, time.Now().Unix())
	if err != nil {
		t.Fatalf("RunGC: %v", err)
	}
	if unreferencedRemoved != 1 {
		t.Errorf("unreferencedRemoved = %d, want 1", unreferencedRemoved)
	}
	if orphanedRemoved != 0 {
		t.Errorf("orphanedRemoved = %d, want 0 (blob is still referenced by a live item)", orphanedRemoved)
	}

	if store.Exists("vault-x", "old-unreferenced") {
		t.Error("unreferenced blob file should have been deleted")
	}
	if !store.Exists("vault-x", "referenced-blob") {
		t.Error("referenced blob file should still exist")
	}
}

func TestAcceptance_GC_FreshUnreferencedKept(t *testing.T) {
	_, db, store := newTestServer(t)
	ctx := context.Background()

	if err := store.Write("vault-x", "fresh-unreferenced", []byte("data")); err != nil {
		t.Fatalf("Write: %v", err)
	}
	insertBlobRow(t, db, "vault-x", "fresh-unreferenced", false, time.Now().Add(-1*time.Hour).Unix())

	unreferencedRemoved, _, err := blobs.RunGC(ctx, db, store, time.Now().Unix())
	if err != nil {
		t.Fatalf("RunGC: %v", err)
	}
	if unreferencedRemoved != 0 {
		t.Errorf("unreferencedRemoved = %d, want 0 (blob is less than 24h old)", unreferencedRemoved)
	}
	if !store.Exists("vault-x", "fresh-unreferenced") {
		t.Error("fresh unreferenced blob should not have been deleted")
	}
}

func TestAcceptance_GC_OrphanedRemovedAfterItemDeleted(t *testing.T) {
	_, db, store := newTestServer(t)
	ctx := context.Background()

	if err := store.Write("vault-x", "was-referenced", []byte("data")); err != nil {
		t.Fatalf("Write: %v", err)
	}
	insertBlobRow(t, db, "vault-x", "was-referenced", true, time.Now().Add(-10*24*time.Hour).Unix())
	// No live item references it (the owning card was deleted more than 7
	// days ago).

	_, orphanedRemoved, err := blobs.RunGC(ctx, db, store, time.Now().Unix())
	if err != nil {
		t.Fatalf("RunGC: %v", err)
	}
	if orphanedRemoved != 1 {
		t.Errorf("orphanedRemoved = %d, want 1", orphanedRemoved)
	}
	if store.Exists("vault-x", "was-referenced") {
		t.Error("orphaned blob file should have been deleted")
	}
}

func TestAcceptance_GC_SurvivesMissingFile(t *testing.T) {
	_, db, store := newTestServer(t)
	ctx := context.Background()

	// Metadata row exists, but the file was already removed by hand.
	insertBlobRow(t, db, "vault-x", "ghost-blob", false, time.Now().Add(-48*time.Hour).Unix())

	unreferencedRemoved, _, err := blobs.RunGC(ctx, db, store, time.Now().Unix())
	if err != nil {
		t.Fatalf("RunGC should not fail when the file is already missing: %v", err)
	}
	if unreferencedRemoved != 1 {
		t.Errorf("unreferencedRemoved = %d, want 1", unreferencedRemoved)
	}
}
