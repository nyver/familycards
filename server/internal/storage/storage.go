// Package storage owns the SQLite connection pools and the write-transaction
// helper. SQLite allows a single writer; splitting reads and writes into two
// pools lets readers proceed under WAL while writes are serialized through
// database/sql's connection queue instead of racing on SQLITE_BUSY.
package storage

import (
	"context"
	"database/sql"
	"fmt"

	_ "modernc.org/sqlite"
)

// DB bundles the read and write pools that both point at the same SQLite
// file. All mutations must go through Write; all queries should prefer Read.
type DB struct {
	Write *sql.DB
	Read  *sql.DB
}

const pragmas = "?_pragma=journal_mode(WAL)&_pragma=synchronous(NORMAL)&_pragma=foreign_keys(ON)&_pragma=busy_timeout(5000)"

// Open opens the write and read pools against path, applying the pragmas
// required by the sync protocol (WAL journaling, foreign keys, a busy
// timeout so concurrent access blocks briefly instead of failing outright).
// The write pool additionally requests _txlock=immediate so BeginTx takes
// the write lock at BEGIN time instead of at the first write statement.
func Open(path string) (*DB, error) {
	dsn := "file:" + path + pragmas

	writeDB, err := sql.Open("sqlite", dsn+"&_txlock=immediate")
	if err != nil {
		return nil, fmt.Errorf("storage: open write pool: %w", err)
	}
	writeDB.SetMaxOpenConns(1)

	readDB, err := sql.Open("sqlite", dsn)
	if err != nil {
		writeDB.Close()
		return nil, fmt.Errorf("storage: open read pool: %w", err)
	}
	readDB.SetMaxOpenConns(4)

	if err := writeDB.Ping(); err != nil {
		writeDB.Close()
		readDB.Close()
		return nil, fmt.Errorf("storage: ping write pool: %w", err)
	}
	if err := readDB.Ping(); err != nil {
		writeDB.Close()
		readDB.Close()
		return nil, fmt.Errorf("storage: ping read pool: %w", err)
	}

	return &DB{Write: writeDB, Read: readDB}, nil
}

// Close closes both pools.
func (db *DB) Close() error {
	writeErr := db.Write.Close()
	readErr := db.Read.Close()
	if writeErr != nil {
		return writeErr
	}
	return readErr
}

// WithImmediateTx runs fn inside a BEGIN IMMEDIATE transaction on the write
// pool, committing on success and rolling back on error or panic. Taking the
// write lock immediately (rather than at first write) avoids upgrading a
// deferred lock mid-transaction, which is what produces SQLITE_BUSY under
// concurrency. db must be a pool opened with _txlock=immediate (see Open).
func WithImmediateTx(ctx context.Context, db *sql.DB, fn func(tx *sql.Tx) error) (err error) {
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("storage: begin tx: %w", err)
	}

	defer func() {
		if p := recover(); p != nil {
			tx.Rollback()
			panic(p)
		}
	}()

	if err := fn(tx); err != nil {
		if rbErr := tx.Rollback(); rbErr != nil {
			return fmt.Errorf("storage: rollback after %w: %v", err, rbErr)
		}
		return err
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("storage: commit: %w", err)
	}
	return nil
}
