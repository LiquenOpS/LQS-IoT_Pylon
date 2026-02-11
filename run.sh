#!/bin/bash
# Start Pylon. Use --mode north | south | full (default: full = north + south on same host)

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

ENV_FILE="$ROOT/config/config.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: config/config.env not found. Run ./setup.sh first." >&2
  exit 1
fi

MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--mode north|south|full]" >&2
      exit 1
      ;;
  esac
done

# Fallback to PYLON_MODE from config if --mode not given
if [[ -z "$MODE" ]]; then
  set -a && source "$ENV_FILE" 2>/dev/null && set +a
  MODE="${PYLON_MODE:-full}"
fi

case "$MODE" in
  north)
    exec /usr/bin/docker compose --env-file "$ENV_FILE" -f "$ROOT/docker-compose.north.yml" up -d
    ;;
  south)
    exec /usr/bin/docker compose --env-file "$ENV_FILE" -f "$ROOT/docker-compose.south.yml" up -d
    ;;
  full)
    exec /usr/bin/docker compose --env-file "$ENV_FILE" \
      -f "$ROOT/docker-compose.north.yml" -f "$ROOT/docker-compose.south.yml" up -d
    ;;
  *)
    echo "Usage: $0 [--mode north|south|full]" >&2
    exit 1
    ;;
esac
