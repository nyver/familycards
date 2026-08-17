// Package migrations applies numbered SQL migrations embedded in the binary.
// Each migration runs at most once, tracked in a schema_migrations table,
// and the whole run happens before the server starts accepting requests.
package migrations

import (
	"context"
	"database/sql"
	"embed"
	"fmt"
	"io/fs"
	"sort"
	"strconv"
	"strings"
)

//go:embed *.sql
var files embed.FS

const createTrackingTable = `
CREATE TABLE IF NOT EXISTS schema_migrations (
    version     INTEGER PRIMARY KEY,
    applied_at  INTEGER NOT NULL
);`

type migration struct {
	version  int
	name     string
	filename string
	sql      string
}

// Apply runs every embedded migration whose version is not yet recorded in
// schema_migrations, in ascending order, each in its own transaction. If a
// migration fails, the database is left exactly as it was before that
// migration (the failing transaction is rolled back and no later migration
// runs).
func Apply(ctx context.Context, db *sql.DB) error {
	migs, err := load()
	if err != nil {
		return fmt.Errorf("migrations: load: %w", err)
	}

	if _, err := db.ExecContext(ctx, createTrackingTable); err != nil {
		return fmt.Errorf("migrations: create tracking table: %w", err)
	}

	applied, err := appliedVersions(ctx, db)
	if err != nil {
		return fmt.Errorf("migrations: read applied versions: %w", err)
	}

	for _, m := range migs {
		if applied[m.version] {
			continue
		}
		if err := applyOne(ctx, db, m); err != nil {
			return fmt.Errorf("migrations: apply %s: %w", m.filename, err)
		}
	}
	return nil
}

func applyOne(ctx context.Context, db *sql.DB, m migration) error {
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if _, err := tx.ExecContext(ctx, m.sql); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, "INSERT INTO schema_migrations (version, applied_at) VALUES (?, unixepoch())", m.version); err != nil {
		return err
	}
	return tx.Commit()
}

func appliedVersions(ctx context.Context, db *sql.DB) (map[int]bool, error) {
	rows, err := db.QueryContext(ctx, "SELECT version FROM schema_migrations")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	applied := make(map[int]bool)
	for rows.Next() {
		var v int
		if err := rows.Scan(&v); err != nil {
			return nil, err
		}
		applied[v] = true
	}
	return applied, rows.Err()
}

func load() ([]migration, error) {
	entries, err := fs.ReadDir(files, ".")
	if err != nil {
		return nil, err
	}

	var migs []migration
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".sql") {
			continue
		}
		version, name, err := parseFilename(e.Name())
		if err != nil {
			return nil, err
		}
		content, err := files.ReadFile(e.Name())
		if err != nil {
			return nil, err
		}
		migs = append(migs, migration{version: version, name: name, filename: e.Name(), sql: string(content)})
	}

	sort.Slice(migs, func(i, j int) bool { return migs[i].version < migs[j].version })
	return migs, nil
}

// parseFilename parses "0001_init.sql" into version 1 and name "init".
func parseFilename(filename string) (int, string, error) {
	base := strings.TrimSuffix(filename, ".sql")
	parts := strings.SplitN(base, "_", 2)
	if len(parts) != 2 {
		return 0, "", fmt.Errorf("migrations: filename %q must be <version>_<name>.sql", filename)
	}
	version, err := strconv.Atoi(parts[0])
	if err != nil {
		return 0, "", fmt.Errorf("migrations: filename %q has non-numeric version: %w", filename, err)
	}
	return version, parts[1], nil
}
