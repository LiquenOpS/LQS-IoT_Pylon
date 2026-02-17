#!/usr/bin/env bash
# View Pylon logs. Use --env-file so compose gets all vars (avoids "variable not set" warnings).
# Usage: ./debug/logs.sh [north|south|full] [service] [--tail N] [--since DURATION] [--out FILE]
#   north  = Orion + mongo-orion
#   south  = iot-agent-json + mongo-iota
#   full   = north + south (default)
#   --tail N     = show last N lines (default 200)
#   --since DUR  = only logs since DURATION (e.g. 1s, 1m); use 1s for "from now"
#   --out FILE   = also write to FILE (tee)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/config/config.env}"

[[ ! -f "$ENV_FILE" ]] && {
  echo "config/config.env not found. Run ./setup.sh first." >&2
  exit 1
}

PART="${1:-full}"
shift || true
SVC_ARGS=()
EXTRA=("--tail" "200")
SINCE=()
OUT_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tail) EXTRA=("--tail" "$2"); shift 2 ;;
    --since) SINCE=("--since" "$2"); shift 2 ;;
    --out|-o) OUT_FILE="$2"; shift 2 ;;
    north|south|full) PART="$1"; shift ;;
    *) SVC_ARGS+=("$1"); shift ;;
  esac
done

case "$PART" in
  north) COMPOSE_FILES=(-f "$ROOT/docker-compose.north.yml") ;;
  south) COMPOSE_FILES=(-f "$ROOT/docker-compose.south.yml") ;;
  full)  COMPOSE_FILES=(-f "$ROOT/docker-compose.north.yml" -f "$ROOT/docker-compose.south.yml") ;;
  *)
    echo "Usage: $0 [north|south|full] [service] [--tail N] [--since DURATION] [--out FILE]" >&2
    exit 1
    ;;
esac

CMD=(docker compose --env-file "$ENV_FILE" "${COMPOSE_FILES[@]}" logs -f "${EXTRA[@]}" "${SINCE[@]}" "${SVC_ARGS[@]}")

if [[ -n "$OUT_FILE" ]]; then
  "${CMD[@]}" 2>&1 | tee "$OUT_FILE"
else
  exec "${CMD[@]}"
fi
