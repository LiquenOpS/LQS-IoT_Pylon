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

ODOO_HOST="${ODOO_HOST:-odoo}"
ODOO_PORT="${ODOO_PORT:-8069}"
ORION_HOST="${ORION_HOST:-localhost}"
ORION_PORT="${ORION_PORT:-1026}"
SUB_URL="http://${ORION_HOST}:${ORION_PORT}/v2/subscriptions"

ODOO_URL="http://${ODOO_HOST}:${ODOO_PORT}/update_last_seen"

echo "Registering Orion subscription for Yardmaster..."
echo "------------------------------------------------"

# Remove existing Yardmaster→Odoo subscriptions to avoid duplicates
SUBS=$(curl -s -L -X GET "$SUB_URL" -H "${HEADER_FIWARE_SERVICE}" -H "${HEADER_FIWARE_SERVICEPATH}" 2>/dev/null || echo "[]")
for id in $(echo "$SUBS" | jq -r --arg url "$ODOO_URL" '
  .[] | select(
    (.subject.entities[]? | .type == "Yardmaster") and
    (.notification.http.url? == $url)
  ) | .id
'); do
  [[ -n "$id" ]] || continue
  echo "Removing duplicate subscription: $id"
  curl -s -o /dev/null -w "" -L -X DELETE "${SUB_URL}/${id}" \
    -H "${HEADER_FIWARE_SERVICE}" \
    -H "${HEADER_FIWARE_SERVICEPATH}" || true
done

HTTP_CODE="$(
  curl -s -o /dev/null -w "%{http_code}" -L -X POST "$SUB_URL" \
    -H "Content-Type: application/json" \
    -H "${HEADER_FIWARE_SERVICE}" \
    -H "${HEADER_FIWARE_SERVICEPATH}" \
    --data-raw "{
  \"description\": \"Notify Odoo when Yardmaster deviceStatus or adopted changes\",
  \"subject\": {
    \"entities\": [
      {
        \"idPattern\": \".*\",
        \"type\": \"Yardmaster\"
      }
    ],
    \"condition\": {
      \"attrs\": [
        \"deviceStatus\",
        \"adopted\"
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

