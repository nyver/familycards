CREATE TABLE vaults (
    id          TEXT PRIMARY KEY,
    created_at  INTEGER NOT NULL,
    last_rev    INTEGER NOT NULL DEFAULT 0,
    max_users   INTEGER NOT NULL DEFAULT 5
);

CREATE TABLE users (
    id                TEXT PRIMARY KEY,
    vault_id          TEXT NOT NULL REFERENCES vaults(id) ON DELETE CASCADE,
    login             TEXT NOT NULL UNIQUE COLLATE NOCASE,
    display_name      TEXT NOT NULL,
    password_hash     TEXT NOT NULL,
    kdf_salt          BLOB NOT NULL,
    kdf_params        TEXT NOT NULL,
    wrapped_vault_key BLOB NOT NULL,
    wrap_nonce        BLOB NOT NULL,
    created_at        INTEGER NOT NULL,
    disabled          INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX idx_users_vault ON users(vault_id);

CREATE TABLE devices (
    id            TEXT PRIMARY KEY,
    user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name          TEXT NOT NULL,
    platform      TEXT NOT NULL,
    refresh_hash  TEXT NOT NULL,
    created_at    INTEGER NOT NULL,
    last_seen_at  INTEGER NOT NULL,
    revoked       INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX idx_devices_user ON devices(user_id);

-- Synced item. The server never inspects nonce/ciphertext contents.
CREATE TABLE items (
    vault_id     TEXT    NOT NULL REFERENCES vaults(id) ON DELETE CASCADE,
    item_id      TEXT    NOT NULL,
    kind         TEXT    NOT NULL,
    rev          INTEGER NOT NULL,
    updated_at   INTEGER NOT NULL,
    deleted      INTEGER NOT NULL DEFAULT 0,
    device_id    TEXT    NOT NULL,
    nonce        BLOB,
    ciphertext   BLOB,
    blob_refs    TEXT    NOT NULL DEFAULT '[]',
    PRIMARY KEY (vault_id, item_id)
);
CREATE INDEX idx_items_rev ON items(vault_id, rev);

CREATE TABLE blobs (
    vault_id    TEXT    NOT NULL,
    blob_id     TEXT    NOT NULL,
    size        INTEGER NOT NULL,
    created_at  INTEGER NOT NULL,
    referenced  INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (vault_id, blob_id)
);

CREATE TABLE invites (
    code_hash         TEXT PRIMARY KEY,
    vault_id          TEXT NOT NULL REFERENCES vaults(id) ON DELETE CASCADE,
    wrapped_vault_key BLOB NOT NULL,
    wrap_nonce        BLOB NOT NULL,
    kdf_salt          BLOB NOT NULL,
    kdf_params        TEXT NOT NULL,
    created_by        TEXT NOT NULL,
    created_at        INTEGER NOT NULL,
    expires_at        INTEGER NOT NULL,
    used_at           INTEGER
);
CREATE INDEX idx_invites_vault ON invites(vault_id);

CREATE TABLE recovery_keys (
    vault_id          TEXT PRIMARY KEY REFERENCES vaults(id) ON DELETE CASCADE,
    wrapped_vault_key BLOB NOT NULL,
    wrap_nonce        BLOB NOT NULL,
    kdf_salt          BLOB NOT NULL,
    kdf_params        TEXT NOT NULL,
    created_at        INTEGER NOT NULL
);
