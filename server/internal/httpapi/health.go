package httpapi

import (
	"context"
	"database/sql"
	"net/http"
)

// Version is set at build time via -ldflags; defaults to "dev".
var Version = "dev"

type healthResponse struct {
	Status    string `json:"status"`
	Version   string `json:"version"`
	DBSize    int64  `json:"db_size"`
	ItemCount int64  `json:"item_count"`
}

// HealthHandler returns GET /v1/health, unauthenticated, used by both
// operators (monitoring) and clients (verifying a server address before
// onboarding).
func HealthHandler(readDB *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()

		var dbSize, itemCount int64
		_ = readDB.QueryRowContext(ctx, "SELECT page_count * page_size FROM pragma_page_count(), pragma_page_size()").Scan(&dbSize)
		_ = readDB.QueryRowContext(ctx, "SELECT COUNT(*) FROM items").Scan(&itemCount)

		WriteJSON(w, http.StatusOK, healthResponse{
			Status:    "ok",
			Version:   Version,
			DBSize:    dbSize,
			ItemCount: itemCount,
		})
	}
}

// Summary logs the hourly operational summary described by the ops spec.
func Summary(ctx context.Context, readDB *sql.DB) (itemCount, blobCount, dbSize int64, err error) {
	if err = readDB.QueryRowContext(ctx, "SELECT COUNT(*) FROM items").Scan(&itemCount); err != nil {
		return
	}
	if err = readDB.QueryRowContext(ctx, "SELECT COUNT(*) FROM blobs").Scan(&blobCount); err != nil {
		return
	}
	err = readDB.QueryRowContext(ctx, "SELECT page_count * page_size FROM pragma_page_count(), pragma_page_size()").Scan(&dbSize)
	return
}
