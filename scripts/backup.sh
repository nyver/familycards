#!/usr/bin/env bash
#
# Triggers a server-side backup via POST /v1/admin/backup and rotates old
# copies, keeping the 14 most recent of each artifact type. Intended to run
# from cron, e.g.:
#   0 3 * * * WALLET_URL=https://wallet.example.com WALLET_ADMIN_TOKEN=... /opt/wallet/scripts/backup.sh
#
# Required environment variables:
#   WALLET_URL          Base URL of the running server, e.g. https://wallet.example.com
#   WALLET_ADMIN_TOKEN   Value configured as WALLET_ADMIN_TOKEN on the server
#   WALLET_BACKUP_DIR     Directory the server writes backups into (its <data>/backups),
#                          reachable from wherever this script runs (typically the same host)
#
# Retention: 14 copies of the database and 14 copies of the blob archive.

set -euo pipefail

: "${WALLET_URL:?WALLET_URL must be set}"
: "${WALLET_ADMIN_TOKEN:?WALLET_ADMIN_TOKEN must be set}"
: "${WALLET_BACKUP_DIR:?WALLET_BACKUP_DIR must be set}"

RETENTION=14

echo "Requesting backup from ${WALLET_URL}..."
response="$(curl --fail --silent --show-error \
  --request POST \
  --header "X-Admin-Token: ${WALLET_ADMIN_TOKEN}" \
  "${WALLET_URL}/v1/admin/backup")"

echo "Backup created: ${response}"

rotate() {
  local pattern="$1"
  # List matching files newest-first, keep the first RETENTION, delete the rest.
  # shellcheck disable=SC2012
  ls -1t ${WALLET_BACKUP_DIR}/${pattern} 2>/dev/null | tail -n "+$((RETENTION + 1))" | while read -r stale; do
    echo "Removing old backup: ${stale}"
    rm -f -- "${stale}"
  done
}

rotate "wallet-*.db"
rotate "blobs-*.tar.gz"

echo "Backup and rotation complete."
