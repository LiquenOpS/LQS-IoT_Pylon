#!/usr/bin/env bash

set -euo pipefail

# Allow overriding env file; default to ./config/.env, then fall back to .env
ENV_FILE="${ENV_FILE:-./config/.env}"
if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
elif [[ -f ".env" ]]; then
  # shellcheck disable=SC1091
  source ".env"
else
  echo "Env file not found. Create ./config/.env or .env first." >&2
  exit 1
fi

ORION_HOST="${ORION_HOST:-orion}"
ORION_PORT="${ORION_PORT:-1026}"

ORION_BROKER="http://${ORION_HOST}:${ORION_PORT}"

echo "Provisioning IoT Agent with Service Groups..."
echo "---------------------------------------------"

HTTP_CODE="$(
  curl -s -o /dev/null -w "%{http_code}" -L -X POST "http://${IOTA_HOST}:${IOTA_NORTH_PORT}/iot/services" \
    -H "${HEADER_CONTENT_TYPE}" \
    -H "${HEADER_FIWARE_SERVICE}" \
    -H "${HEADER_FIWARE_SERVICEPATH}" \
    --data-raw "{
    \"services\": [
        {
            \"apikey\": \"SignKey\",
            \"cbroker\": \"${ORION_BROKER}\",
            \"entity_type\": \"Signage\",
            \"resource\": \"/iot/json\"
        },
        {
            \"apikey\": \"SignKeyForNeoPixel\",
            \"cbroker\": \"${ORION_BROKER}\",
            \"entity_type\": \"NeoPixel\",
            \"resource\": \"/iot/json\"
        }
    ]
  }"
)"

echo "HTTP status: ${HTTP_CODE}"
if [[ "${HTTP_CODE}" == "201" ]]; then
  echo "Done. Service groups created successfully."
else
  echo "Warning: expected 201. Check IoT Agent logs." >&2
fi

