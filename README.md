# Family Card Wallet

A self-hosted, end-to-end encrypted loyalty card wallet for a family — a Stocard-style app you run yourself. One shared vault, 1–5 users, offline-first, no vendor lock-in.

Screenshots: _placeholder — add screenshots of the card list, card detail (barcode), and onboarding once available._

**Current status: server and mobile client both implemented and tested** through account/security settings (member management, invites, biometric unlock, trash, encrypted export, server diagnostics, sign-out). Remaining work is documentation polish and final release verification — see [Project status](#project-status).

## Key properties

- **One shared vault per family.** Every card is visible to every member; there is no per-user ACL — a deliberate simplification.
- **Offline-first.** The mobile app reads exclusively from a local database; the server exists only to synchronize between devices.
- **End-to-end encrypted.** The server stores ciphertext and revision metadata only. It cannot read card numbers, photos, or notes — see [docs/THREAT-MODEL.md](docs/THREAT-MODEL.md) for exactly what it can and cannot see.
- **Self-hosted.** A single static binary plus one SQLite file and a blob directory. Deploys to a home NAS or a small VPS in minutes — see [docs/DEPLOY.md](docs/DEPLOY.md).

## Project status

| Component | Status |
|---|---|
| Sync server (`server/`) | **Done.** Auth, invites/membership, delta sync with conflict resolution, encrypted blob storage with garbage collection, admin backup. |
| Mobile client (`mobile/`) | **Done.** Onboarding, client-side crypto, card CRUD with barcode scanning, the client sync engine, and account/security settings (members, invites, biometric unlock, trash, encrypted export, server diagnostics, sign-out). |
| Documentation & release | In progress — this pass. |

See [openspec/changes/add-family-card-wallet/tasks.md](openspec/changes/add-family-card-wallet/tasks.md) for the full task breakdown and [DECISIONS.md](DECISIONS.md) for implementation decisions and known environment limitations (no C compiler, so `go test -race` and `flutter test -race`-equivalent concurrency checks were not run; no Docker, so `docker compose up` was not exercised — the underlying binary and Dockerfile were verified separately, see DECISIONS.md).

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

## Quick start: mobile client

Requires Flutter 3.24+ / Dart 3.5+, and the Android SDK to build an APK.

```bash
cd mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates drift/l10n code
flutter analyze
flutter test
```

Run against a local server (start the server first, see above):

```bash
flutter run
```

On first launch, pick "Create a family vault", point it at your server's address, and enter the `WALLET_BOOTSTRAP_TOKEN`. Save the recovery phrase shown once — it is the only way back into the vault if the account password is lost. Additional family members join with an invite code generated from Settings → Family members.

Release build:

```bash
flutter build apk --release
```

## API

Full endpoint reference: [docs/API.md](docs/API.md).

## Sync protocol

The server assigns each accepted item a monotonically increasing revision per vault and resolves conflicting pushes with a deterministic last-writer-wins rule, so independently offline-edited devices always converge to the same state. The mobile client's sync engine (`mobile/lib/features/sync/`) implements the identical rule, verified against a shared test-vector fixture. Full details: [docs/SYNC.md](docs/SYNC.md).

## Threat model

What the server can and cannot see, trust boundaries, and explicitly accepted trade-offs (e.g. removing a member does not rotate the vault key): [docs/THREAT-MODEL.md](docs/THREAT-MODEL.md).

## Repository layout

```
server/            Go sync server
  cmd/wallet/       entry point
  internal/         config, httpapi, auth, membership, sync, blobs, admin,
                     storage, migrations, crypto, ratelimit, model, idgen, logging
mobile/            Flutter client
  lib/core/         db (drift), net (dio client), crypto, biometrics, storage
  lib/features/     auth (onboarding/session), cards (CRUD/scanner), sync
                     (client sync engine), settings (members/invites/security/
                     trash/export/server diagnostics)
  test/             unit, widget, and server-backed integration tests
deploy/            docker-compose.yml, wallet.service, Caddyfile
docs/              API.md, SYNC.md, DEPLOY.md, THREAT-MODEL.md
scripts/           backup.sh, gen-logos.py
testdata/          lww_vectors.json — conflict-resolution test vectors shared
                    between the Go server and the Dart client
DECISIONS.md       implementation decisions and their rationale
```

## Development conventions

- Server: `go build ./...`, `go vet ./...`, `go test ./...` must pass before any commit (this environment has no C compiler, so `-race` could not be run; see DECISIONS.md).
- Client: `flutter analyze` (zero issues) and `flutter test` must pass before any commit.
- Comments in code and in example configs are in English.
- Design documentation in `docs/` is in Russian, matching the rest of this repository's planning artifacts under `openspec/`.
