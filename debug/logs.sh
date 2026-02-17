#!/usr/bin/env bash
# View Pylon logs. Use --env-file so compose gets all vars (avoids "variable not set" warnings).
# Usage: ./debug/logs.sh [north|south|full] [service] [--tail N]
#   north  = Orion + mongo-orion
#   south  = iot-agent-json + mongo-iota
#   full   = both (default)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/config/config.env}"

[[ ! -f "$ENV_FILE" ]] && {
  echo "config/config.env not found. Run ./setup.sh first." >&2
  exit 1
}

PART="${1:-full}"
shift || true
SVC=""
EXTRA=("--tail" "200")
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tail) EXTRA=("--tail" "$2"); shift 2 ;;
    north|south|full) PART="$1"; shift ;;
    *) SVC="$1"; shift ;;
  esac
done

case "$PART" in
  north)
    exec docker compose --env-file "$ENV_FILE" -f "$ROOT/docker-compose.north.yml" logs -f "${EXTRA[@]}" ${SVC:+"$SVC"}
    ;;
  south)
    exec docker compose --env-file "$ENV_FILE" -f "$ROOT/docker-compose.south.yml" logs -f "${EXTRA[@]}" ${SVC:+"$SVC"}
    ;;
  full)
    exec docker compose --env-file "$ENV_FILE" \
      -f "$ROOT/docker-compose.north.yml" -f "$ROOT/docker-compose.south.yml" \
      logs -f "${EXTRA[@]}" ${SVC:+"$SVC"}
    ;;
  *)
    echo "Usage: $0 [north|south|full] [service] [--tail N]" >&2
    exit 1
    ;;
esac
