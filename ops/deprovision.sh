#!/usr/bin/env bash
# Deprovision: remove Pylon service groups (IOTA) and Yardmaster subscription (Orion).
# Inverse of provision (option 2).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/config/config.env}"
if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
else
  echo "Config not found. Run setup.sh first." >&2
  exit 1
fi

IOTA_HOST="${IOTA_HOST:-localhost}"
ORION_HOST="${ORION_HOST:-localhost}"
ORION_PORT="${ORION_PORT:-1026}"
ODOO_HOST="${ODOO_HOST:-odoo}"
ODOO_PORT="${ODOO_PORT:-8069}"
SUB_URL="http://${ORION_HOST}:${ORION_PORT}/v2/subscriptions"
ODOO_URL="http://${ODOO_HOST}:${ODOO_PORT}/update_last_seen"

echo "==> Deprovisioning (service groups + subscription)..."
echo ""

# 1. Delete Orion device subscription(s) (LEDStrip/Signage -> Odoo)
echo "Removing Orion subscription (LEDStrip/Signage -> Odoo)..."
SUBS=$(curl -s -L -X GET "$SUB_URL" -H "${HEADER_FIWARE_SERVICE}" -H "${HEADER_FIWARE_SERVICEPATH}" 2>/dev/null || echo "[]")
COUNT=0
for id in $(echo "$SUBS" | jq -r --arg url "$ODOO_URL" '
  .[] | select(.notification.http.url? == $url) | .id
'); do
  [[ -n "$id" ]] || continue
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -L -X DELETE "${SUB_URL}/${id}" \
    -H "${HEADER_FIWARE_SERVICE}" \
    -H "${HEADER_FIWARE_SERVICEPATH}")
  if [[ "$HTTP_CODE" == "204" ]]; then
    echo "  Deleted subscription: $id"
    ((COUNT++)) || true
  else
    echo "  Failed to delete $id: HTTP $HTTP_CODE" >&2
  fi
done
if [[ "$COUNT" -eq 0 ]]; then
  echo "  (none found)"
fi
echo ""

# 2. Delete IOTA service groups (LEDStrip, Signage)
echo "Removing IoT Agent service groups (apikey=YardmasterKey, resource=/iot/json)..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -L -X DELETE \
  "http://${IOTA_HOST}:${IOTA_NORTH_PORT}/iot/services?resource=%2Fiot%2Fjson&apikey=YardmasterKey" \
  -H "${HEADER_FIWARE_SERVICE}" \
  -H "${HEADER_FIWARE_SERVICEPATH}")
if [[ "$HTTP_CODE" == "204" ]]; then
  echo "  Deleted."
else
  echo "  HTTP $HTTP_CODE (may not exist)" >&2
fi

echo ""
echo "Done."
