# API Reference

All endpoints are under `/v1`, use JSON request/response bodies (`Content-Type: application/json`) except where noted, and require `Authorization: Bearer <access_token>` except for the endpoints explicitly marked **public**. Binary fields (keys, salts, nonces, ciphertext) are base64-encoded using the standard alphabet with padding.

The server never has access to plaintext card data: `nonce` and `ciphertext` are opaque bytes it stores and returns unchanged.

## Errors

Errors are returned as:

```json
{ "error": "bad_request", "message": "human-readable detail" }
```

Common `error` codes: `bad_request` (400), `unauthorized` (401), `forbidden` (403), `not_found` (404), `conflict` (409), `gone` (410), `payload_too_large` (413), `rate_limited` (429), `internal_error` (500).

## Authentication

### `POST /v1/auth/bootstrap` — public, requires `X-Bootstrap-Token` header

Creates the vault and its first user. Fails with `409` if any user already exists.

Request:
```json
{
  "login": "alice",
  "display_name": "Alice",
  "password": "...",
  "kdf_salt": "base64",
  "kdf_params": {"m": 65536, "t": 3, "p": 1},
  "wrapped_vault_key": "base64",
  "wrap_nonce": "base64",
  "recovery": {
    "wrapped_vault_key": "base64",
    "wrap_nonce": "base64",
    "kdf_salt": "base64",
    "kdf_params": {"m": 65536, "t": 3, "p": 1}
  },
  "device": {"name": "Alice's Phone", "platform": "android"}
}
```

Response `201`:
```json
{ "user_id": "...", "vault_id": "...", "device_id": "...", "access_token": "...", "refresh_token": "..." }
```

### `POST /v1/auth/prelogin` — public

Returns the KDF salt/params needed to derive KEK before sending a password. For an unknown login, returns a deterministic fake salt (indistinguishable from a real one) rather than an error.

Request: `{"login": "alice"}`
Response `200`: `{"kdf_salt": "base64", "kdf_params": {...}}`

### `POST /v1/auth/login` — public

Request:
```json
{ "login": "alice", "password": "...", "device": {"id": "optional-existing-device-id", "name": "...", "platform": "android"} }
```

Response `200`:
```json
{
  "user_id": "...", "vault_id": "...", "device_id": "...",
  "access_token": "...", "refresh_token": "...",
  "wrapped_vault_key": "base64", "wrap_nonce": "base64",
  "kdf_salt": "base64", "kdf_params": {...}
}
```

`401` for invalid credentials (same message for unknown login and wrong password). `403` if the account is disabled. `409` if the vault's 10-device limit is reached.

### `POST /v1/auth/refresh` — public

Request: `{"refresh_token": "..."}`
Response `200`: `{"access_token": "...", "refresh_token": "..."}` (rotated - the old refresh token stops working).

`401` for an unknown, expired, or already-rotated token. Replaying a token that was already rotated away from revokes every device belonging to that user (treated as a compromise signal).

### `POST /v1/auth/logout` — requires bearer auth

Request: `{"refresh_token": "..."}`. Always returns `204`, whether or not the token was valid.

### `POST /v1/auth/password` — requires bearer auth

Request:
```json
{
  "old_password": "...", "new_password": "...",
  "kdf_salt": "base64", "kdf_params": {...},
  "wrapped_vault_key": "base64", "wrap_nonce": "base64"
}
```

Response `204`. `401` if `old_password` does not match.

### `POST /v1/auth/recovery/prelogin` — public

Returns the recovery-phrase KDF salt/params *and* the wrapped vault key needed to derive RKEK and unwrap VK locally, in one round trip - mirroring how `/v1/auth/login` returns the wrap after password verification. This is safe to serve without any verification because the wrap is opaque ciphertext: useless to anyone who cannot derive RKEK, which requires the actual 12-word phrase (128 bits of entropy). Unknown logins get a deterministic fake salt and a deterministic fake wrap of the same shape and length, so the response can never be used to distinguish a real account from a nonexistent one.

Request: `{"login": "alice"}`
Response `200`: `{"kdf_salt": "base64", "kdf_params": {...}, "wrapped_vault_key": "base64", "wrap_nonce": "base64"}`

### `POST /v1/auth/recovery/redeem` — public

Resets a forgotten password using the 12-word recovery phrase. The client has already unwrapped VK locally (using RKEK against the wrap from `recovery/prelogin`) and generated a brand new password-wrapped VK by the time it calls this. `verifier` is the phrase's canonical string form (space-joined, lowercase), checked server-side against the stored `verifier_hash` set at bootstrap - this is what lets the server authenticate a redeem attempt without ever being able to derive VK itself.

Request:
```json
{
  "login": "alice", "verifier": "abandon ability able ...", "new_password": "...",
  "kdf_salt": "base64", "kdf_params": {...},
  "wrapped_vault_key": "base64", "wrap_nonce": "base64",
  "device": {"name": "...", "platform": "android"}
}
```

Response `200`: `{"user_id": "...", "vault_id": "...", "device_id": "...", "access_token": "...", "refresh_token": "..."}`. A successful recovery revokes every other device on the account, since it is a strong signal the previous password may have been compromised. `401` for an unknown login or a verifier that does not match.

### `GET /v1/me` — requires bearer auth

Response `200`:
```json
{
  "user": {"id": "...", "login": "...", "display_name": "..."},
  "vault": {"id": "...", "max_users": 5, "user_count": 2},
  "server_rev": 1287
}
```

## Membership

### `POST /v1/invites` — requires bearer auth

Request:
```json
{
  "code_hash": "sha256-hex-of-invite-code",
  "wrapped_vault_key": "base64", "wrap_nonce": "base64",
  "kdf_salt": "base64", "kdf_params": {...},
  "ttl_hours": 24
}
```

Response `201`: `{"code_hash": "...", "expires_at": 1755300000}`. `409` if active users plus active invites already meet `max_users`.

### `GET /v1/invites/{code_hash}` — public

Response `200`: `{"vault_id": "...", "wrapped_vault_key": "base64", "wrap_nonce": "base64", "kdf_salt": "base64", "kdf_params": {...}}`.
`404` unknown, `410` used or expired.

### `POST /v1/invites/{code_hash}/redeem` — public

Request:
```json
{
  "login": "bob", "display_name": "Bob", "password": "...",
  "kdf_salt": "base64", "kdf_params": {...},
  "wrapped_vault_key": "base64", "wrap_nonce": "base64",
  "device": {"name": "Bob's Phone", "platform": "ios"}
}
```

Response `200`: same shape as login. `410` if the invite was already used or has expired, `409` if the login is taken or the vault is at capacity.

### `DELETE /v1/invites/{code_hash}` — requires bearer auth

Cancels an active invite belonging to the caller's vault. `204` on success, `404` if unknown or belonging to another vault.

### `GET /v1/members` — requires bearer auth

Response `200`: array of
```json
{
  "user_id": "...", "display_name": "...", "login": "...",
  "created_at": 1755300000, "last_seen_at": 1755300000,
  "devices": [{"id": "...", "name": "...", "platform": "android", "created_at": 0, "last_seen_at": 0, "revoked": false}]
}
```

### `DELETE /v1/members/{user_id}` — requires bearer auth

Revokes a member's access (disables the account and revokes all their devices). `204` on success, `409` if this would remove the vault's last active member.

## Sync

### `GET /v1/sync/changes?since={rev}&limit={n}` — requires bearer auth

`limit` defaults to 200, capped at 500.

Response `200`:
```json
{
  "server_rev": 1287,
  "next_since": 1287,
  "has_more": false,
  "items": [
    {
      "item_id": "...", "kind": "card", "rev": 1287, "updated_at": 1755300000000,
      "deleted": false, "device_id": "...", "nonce": "base64", "ciphertext": "base64",
      "blob_refs": ["hex-blob-id"]
    }
  ]
}
```

`nonce` and `ciphertext` are `null` for tombstones (`deleted: true`).

### `POST /v1/sync/push` — requires bearer auth

Request:
```json
{
  "device_id": "must-match-the-authenticated-device",
  "items": [
    {
      "item_id": "...", "kind": "card", "base_rev": 801, "updated_at": 1755300100000,
      "deleted": false, "nonce": "base64", "ciphertext": "base64", "blob_refs": []
    }
  ]
}
```

At most 100 items per batch. Every referenced blob must already have been uploaded via `POST /v1/blobs`, or the whole batch is rejected with `409`.

Response `200`:
```json
{
  "server_rev": 1290,
  "accepted": [{"item_id": "...", "rev": 1288}],
  "conflicts": [
    {"item_id": "...", "rev": 1205, "updated_at": 0, "deleted": false, "device_id": "...", "nonce": "base64", "ciphertext": "base64", "blob_refs": []}
  ]
}
```

A conflict entry is the server's current version of that item; the client is expected to apply it locally and drop the conflicting local write. See [SYNC.md](SYNC.md) for the conflict resolution rule.

## Blobs

### `POST /v1/blobs` — requires bearer auth

Body: `application/octet-stream`, exactly `nonce || ciphertext`. Header `X-Blob-Id: <hex sha256 of the body>` is required and verified server-side. Limit 8 MiB.

Response `201` (new) or `200` (already existed, idempotent - the file is not rewritten): `{"blob_id": "...", "size": 12345}`. `400` if `X-Blob-Id` does not match the body's hash.

### `GET /v1/blobs/{blob_id}` — requires bearer auth

Response `200`, `Content-Type: application/octet-stream`, body is the raw stored bytes. `404` if unknown or belonging to another vault.

## Operations

### `GET /v1/health` — public

Response `200`: `{"status": "ok", "version": "...", "db_size": 123456, "item_count": 42}`. Also used by clients to validate a server address before onboarding.

### `POST /v1/admin/backup` — requires `X-Admin-Token` header (not bearer auth)

Triggers an immediate, consistent backup: `VACUUM INTO` for the database plus a gzipped tar of the blob directory. Response `200`:
```json
{ "database_backup_path": "...", "database_size": 123456, "blob_archive_path": "...", "blob_archive_size": 654321 }
```

`401` for a wrong token, `404` if `WALLET_ADMIN_TOKEN` is not configured (the endpoint is not exposed at all in that case).
