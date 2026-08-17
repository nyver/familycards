# Family Card Wallet

A self-hosted, end-to-end encrypted loyalty card wallet for a family — a Stocard-style app you run yourself. One shared vault, 1–5 users, offline-first, no vendor lock-in.

**Current status: the sync server is complete and tested. The mobile client is not yet implemented** — see [Project status](#project-status) below.

## Key properties

- **One shared vault per family.** Every card is visible to every member; there is no per-user ACL — a deliberate simplification.
- **Offline-first.** The mobile app (once built) reads exclusively from a local database; the server exists only to synchronize between devices.
- **End-to-end encrypted.** The server stores ciphertext and revision metadata only. It cannot read card numbers, photos, or notes — see [docs/THREAT-MODEL.md](docs/THREAT-MODEL.md) for exactly what it can and cannot see.
- **Self-hosted.** A single static binary plus one SQLite file and a blob directory. Deploys to a home NAS or a small VPS in minutes — see [docs/DEPLOY.md](docs/DEPLOY.md).

## Project status

| Component | Status |
|---|---|
| Sync server (`server/`) | **Done.** Auth, invites/membership, delta sync with conflict resolution, encrypted blob storage with garbage collection, admin backup. All milestones tested and passing. |
| Mobile client (`mobile/`) | **Not implemented.** Requires a Flutter/Dart toolchain that was unavailable in the environment this was built in. |

See [openspec/changes/add-family-card-wallet/tasks.md](openspec/changes/add-family-card-wallet/tasks.md) for the full task breakdown and [DECISIONS.md](DECISIONS.md) for implementation decisions and known environment limitations (no C compiler for `-race`, no Docker, no Flutter SDK in this environment).

## Quick start: server

Requires Go 1.23+.

```bash
cd server
go build ./...
go vet ./...
go test ./...
```

Run it:

```bash
export WALLET_JWT_SECRET="$(openssl rand -base64 32)"
export WALLET_BOOTSTRAP_TOKEN="$(openssl rand -base64 24)"
export WALLET_ALLOW_INSECURE=true   # local development only, see below
go run ./cmd/wallet
```

```bash
curl http://localhost:8443/v1/health
```

See [config.example.yaml](config.example.yaml) for every environment variable the server reads.

### Docker Compose

```bash
cd deploy
# create a .env file with WALLET_JWT_SECRET, WALLET_BOOTSTRAP_TOKEN, etc. — see config.example.yaml
docker compose up -d --build
```

### Production deployment

See [docs/DEPLOY.md](docs/DEPLOY.md) for a full walkthrough: systemd unit, Caddy as a TLS-terminating reverse proxy, and scheduled backups.

## API

Full endpoint reference: [docs/API.md](docs/API.md).

## Sync protocol

The server assigns each accepted item a monotonically increasing revision per vault and resolves conflicting pushes with a deterministic last-writer-wins rule, so independently offline-edited devices always converge to the same state. Full details, including the shared conflict-resolution test vectors both the server and (eventually) the mobile client must agree on: [docs/SYNC.md](docs/SYNC.md).

## Threat model

What the server can and cannot see, trust boundaries, and explicitly accepted trade-offs (e.g. removing a member does not rotate the vault key): [docs/THREAT-MODEL.md](docs/THREAT-MODEL.md).

## Repository layout

```
server/            Go sync server
  cmd/wallet/       entry point
  internal/         config, httpapi, auth, membership, sync, blobs, admin,
                     storage, migrations, crypto, ratelimit, model, idgen, logging
mobile/            Flutter client (not yet implemented)
deploy/            docker-compose.yml, wallet.service, Caddyfile
docs/              API.md, SYNC.md, DEPLOY.md, THREAT-MODEL.md
scripts/           backup.sh
testdata/          lww_vectors.json — conflict-resolution test vectors shared
                    between the Go server and the (future) Dart client
DECISIONS.md       implementation decisions and their rationale
```

## Development conventions

- Server tests: `go build ./...`, `go vet ./...`, `go test ./...` must pass before any commit (this environment cannot run `-race`; see DECISIONS.md).
- Comments in code and in example configs are in English.
- Design documentation in `docs/` is in Russian, matching the rest of this repository's planning artifacts under `openspec/`.
