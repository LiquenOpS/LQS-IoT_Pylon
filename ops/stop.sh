#!/bin/bash
# Stop Pylon stack. Reads PYLON_MODE from config.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/config/config.env"
[ ! -f "$ENV_FILE" ] && exit 0

set -a && source "$ENV_FILE" && set +a
MODE="${PYLON_MODE:-full}"

case "$MODE" in
  north)
    docker compose --env-file "$ENV_FILE" -f "$ROOT/docker-compose.north.yml" down "$@"
    ;;
  south)
    docker compose --env-file "$ENV_FILE" -f "$ROOT/docker-compose.south.yml" down "$@"
    ;;
  full)
    docker compose --env-file "$ENV_FILE" \
      -f "$ROOT/docker-compose.north.yml" -f "$ROOT/docker-compose.south.yml" down "$@"
    ;;
  *)
    echo "Unknown PYLON_MODE: $MODE" >&2
    exit 1
    ;;
esac
