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

# IOTA config group: (apikey, resource) is unique. One group per apikey for /iot/json.
# Device-level entity_type (LEDStrip/Signage) is set at device provision (Yardmaster).
# Create one group - entity_type here is default for autoprovision only.
echo "Provisioning IoT Agent service group (YardmasterKey, LEDStrip+Signage)..."
echo "------------------------------------------------------"

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
            \"entity_type\": \"LEDStrip\",
            \"resource\": \"/iot/json\"
        }
    ]
  }"
)"
case "${HTTP_CODE}" in
  201) echo "Created" ;;
  409) echo "Already exists" ;;
  *) echo "HTTP ${HTTP_CODE} (expected 201/409)" >&2 ;;
esac

echo "Done."

