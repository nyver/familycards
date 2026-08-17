-- Tracks refresh token hashes that have been rotated away from, so a
-- replayed (stolen) old refresh token can be told apart from one that was
-- simply never valid. devices.refresh_hash only ever holds the *current*
-- hash, so without this table rotation makes the old hash indistinguishable
-- from garbage.
CREATE TABLE retired_refresh_tokens (
    hash        TEXT PRIMARY KEY,
    user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    retired_at  INTEGER NOT NULL
);
CREATE INDEX idx_retired_refresh_tokens_user ON retired_refresh_tokens(user_id);
