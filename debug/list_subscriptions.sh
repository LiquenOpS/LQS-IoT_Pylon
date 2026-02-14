#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/config/config.env}"
if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
else
  echo "Env file not found. Copy config.example to config, edit config/config.env." >&2
  exit 1
fi

ORION_HOST="${ORION_HOST:-localhost}"
echo "Orion subscriptions for ${FIWARE_SERVICE}..."
curl -s -L -X GET "http://${ORION_HOST}:${ORION_PORT}/v2/subscriptions" \
  -H "${HEADER_FIWARE_SERVICE}" \
  -H "${HEADER_FIWARE_SERVICEPATH}" | jq .
