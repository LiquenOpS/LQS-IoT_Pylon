#!/bin/bash
# Start Pylon stack (docker compose up -d). For stop: docker compose down

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

ENV_FILE="$ROOT/config/config.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: config/config.env not found. Run ./setup.sh first." >&2
  exit 1
fi

exec /usr/bin/docker compose --env-file "$ENV_FILE" up -d
