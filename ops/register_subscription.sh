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

ODOO_HOST="${ODOO_HOST:-odoo}"
ODOO_PORT="${ODOO_PORT:-8069}"
ORION_PORT="${ORION_PORT:-1026}"

ODOO_URL="http://${ODOO_HOST}:${ODOO_PORT}/update_last_seen"

echo "Registering Orion subscription for Signage & NeoPixel..."
echo "---------------------------------------------------------"

HTTP_CODE="$(
  curl -s -o /dev/null -w "%{http_code}" -L -X POST "http://${HOST}:${ORION_PORT}/v2/subscriptions" \
    -H "Content-Type: application/json" \
    -H "${HEADER_FIWARE_SERVICE}" \
    -H "${HEADER_FIWARE_SERVICEPATH}" \
    --data-raw "{
  \"description\": \"Notify Odoo when display status changes\",
  \"subject\": {
    \"entities\": [
      {
        \"idPattern\": \".*\",
        \"type\": \"Signage\"
      },
      {
        \"idPattern\": \".*\",
        \"type\": \"NeoPixel\"
      }
    ],
    \"condition\": {
      \"attrs\": [
        \"device_status\"
      ]
    }
  },
  \"notification\": {
    \"http\": {
      \"url\": \"${ODOO_URL}\"
    },
    \"attrs\": [],
    \"attrsFormat\": \"keyValues\"
  }
}"
)"

echo "HTTP status: ${HTTP_CODE}"
if [[ "${HTTP_CODE}" == "201" || "${HTTP_CODE}" == "204" ]]; then
  echo "Done. Subscription registered successfully."
else
  echo "Warning: expected 201/204. Check Orion logs." >&2
fi

