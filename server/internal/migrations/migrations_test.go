package migrations

import (
	"context"
	"database/sql"
	"testing"

	_ "modernc.org/sqlite"
)

func openMemDB(t *testing.T) *sql.DB {
	t.Helper()
	db, err := sql.Open("sqlite", "file::memory:?cache=shared")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	db.SetMaxOpenConns(1)
	t.Cleanup(func() { db.Close() })
	return db
}

func TestApply_FreshDatabase(t *testing.T) {
	db := openMemDB(t)
	ctx := context.Background()

	if err := Apply(ctx, db); err != nil {
		t.Fatalf("Apply: %v", err)
	}

	tables := []string{"vaults", "users", "devices", "items", "blobs", "invites", "recovery_keys", "retired_refresh_tokens"}
	for _, table := range tables {
		var name string
		err := db.QueryRowContext(ctx, "SELECT name FROM sqlite_master WHERE type='table' AND name=?", table).Scan(&name)
		if err != nil {
			t.Errorf("table %q missing after Apply: %v", table, err)
		}
	}
}

func TestApply_Idempotent(t *testing.T) {
	db := openMemDB(t)
	ctx := context.Background()

	if err := Apply(ctx, db); err != nil {
		t.Fatalf("first Apply: %v", err)
	}

	var firstCount int
	if err := db.QueryRowContext(ctx, "SELECT COUNT(*) FROM schema_migrations").Scan(&firstCount); err != nil {
		t.Fatalf("count migrations: %v", err)
	}
	if firstCount == 0 {
		t.Fatal("expected at least one migration to be recorded")
	}

	if err := Apply(ctx, db); err != nil {
		t.Fatalf("second Apply should not fail: %v", err)
	}

	var secondCount int
	if err := db.QueryRowContext(ctx, "SELECT COUNT(*) FROM schema_migrations").Scan(&secondCount); err != nil {
		t.Fatalf("count migrations: %v", err)
	}
	if secondCount != firstCount {
		t.Errorf("schema_migrations count after re-Apply = %d, want %d (migration re-applied)", secondCount, firstCount)
	}
}

func TestParseFilename(t *testing.T) {
	cases := []struct {
		filename    string
		wantVersion int
		wantName    string
		wantErr     bool
	}{
		{"0001_init.sql", 1, "init", false},
		{"0012_add_index.sql", 12, "add_index", false},
		{"noversion.sql", 0, "", true},
		{"abc_init.sql", 0, "", true},
	}
	for _, c := range cases {
		v, n, err := parseFilename(c.filename)
		if c.wantErr {
			if err == nil {
				t.Errorf("parseFilename(%q): expected error", c.filename)
			}
			continue
		}
		if err != nil {
			t.Errorf("parseFilename(%q): unexpected error: %v", c.filename, err)
			continue
		}
		if v != c.wantVersion || n != c.wantName {
			t.Errorf("parseFilename(%q) = (%d, %q), want (%d, %q)", c.filename, v, n, c.wantVersion, c.wantName)
		}
	}
}
