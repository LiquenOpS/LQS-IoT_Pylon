#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TIMESTAMP="$(date +'%Y%m%d-%H%M%S')"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
CONTAINER_NAME="${MONGO_CONTAINER_NAME:-db-mongo-orion}"
MONGO_DB_PORT="${MONGO_DB_PORT:-27017}"

mkdir -p "${BACKUP_DIR}"

ARCHIVE_PATH="${BACKUP_DIR}/mongo-backup-${TIMESTAMP}.gz"

echo "==> [backup] Dumping MongoDB from container '${CONTAINER_NAME}'..."

if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
  docker exec "${CONTAINER_NAME}" sh -c "mongodump --archive --gzip" > "${ARCHIVE_PATH}"
else
  echo "Container '${CONTAINER_NAME}' not running; trying direct localhost:${MONGO_DB_PORT}..."
  mongodump --host localhost --port "${MONGO_DB_PORT}" --archive --gzip > "${ARCHIVE_PATH}"
fi

echo "==> [backup] Backup written to ${ARCHIVE_PATH}"

