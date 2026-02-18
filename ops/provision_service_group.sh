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

IOTA_CB_HOST="${IOTA_CB_HOST:-orion}"
ORION_PORT="${ORION_PORT:-1026}"
ORION_BROKER="http://${IOTA_CB_HOST}:${ORION_PORT}"

# Service groups for LEDStrip and Signage (one per entity type)
echo "Provisioning IoT Agent service groups (LEDStrip, Signage)..."
echo "------------------------------------------------------"

for ENTITY_TYPE in LEDStrip Signage; do
  HTTP_CODE="$(
    curl -s -o /dev/null -w "%{http_code}" -L -X POST "http://localhost:${IOTA_NORTH_PORT}/iot/services" \
      -H "${HEADER_CONTENT_TYPE}" \
      -H "${HEADER_FIWARE_SERVICE}" \
      -H "${HEADER_FIWARE_SERVICEPATH}" \
      --data-raw "{
      \"services\": [
          {
              \"apikey\": \"YardmasterKey\",
              \"cbroker\": \"${ORION_BROKER}\",
              \"entity_type\": \"${ENTITY_TYPE}\",
              \"resource\": \"/iot/json\"
          }
      ]
    }"
  )"
  echo "${ENTITY_TYPE}: HTTP ${HTTP_CODE}"
  if [[ "${HTTP_CODE}" != "201" ]] && [[ "${HTTP_CODE}" != "409" ]]; then
    echo "Warning: expected 201 or 409 (exists). Check IoT Agent logs." >&2
  fi
done

echo "Done."

