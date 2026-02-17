#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"
[ -f "${ROOT_DIR}/config/config.env" ] && set -a && source "${ROOT_DIR}/config/config.env" && set +a

TIMESTAMP="$(date +'%Y%m%d-%H%M%S')"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
CONTAINER_NAME="${MONGO_ORION_CONTAINER:-db-mongo-orion}"
MONGO_PORT="${MONGO_ORION_PORT:-27017}"

mkdir -p "${BACKUP_DIR}"

ARCHIVE_PATH="${BACKUP_DIR}/mongo-backup-${TIMESTAMP}.gz"

echo "==> [backup] Dumping MongoDB from container '${CONTAINER_NAME}'..."

if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
  docker exec "${CONTAINER_NAME}" sh -c "mongodump --archive --gzip" > "${ARCHIVE_PATH}"
else
  echo "Container '${CONTAINER_NAME}' not running; trying direct localhost:${MONGO_PORT}..."
  mongodump --host localhost --port "${MONGO_PORT}" --archive --gzip > "${ARCHIVE_PATH}"
fi

echo "==> [backup] Backup written to ${ARCHIVE_PATH}"

