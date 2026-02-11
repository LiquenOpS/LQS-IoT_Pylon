#!/usr/bin/env bash
# Interactive: list entities, pick one, delete from Orion.
# Run from Pylon (North) host where Orion is reachable.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/config/config.env}"
[[ -f "${ENV_FILE}" ]] || { echo "Config not found. Run setup.sh first." >&2; exit 1; }
# shellcheck disable=SC1090
source "${ENV_FILE}"

ORION_HOST="${ORION_HOST:-localhost}"
ORION_URL="http://${ORION_HOST}:${ORION_PORT}"
ENTITIES_URL="${ORION_URL}/v2/entities"

TYPE_FILTER="${1:-Yardmaster}"
echo "Fetching entities (type=${TYPE_FILTER})..."
ENTITIES=$(curl -s -L -X GET "${ENTITIES_URL}?type=${TYPE_FILTER}" \
  -H "${HEADER_FIWARE_SERVICE}" \
  -H "${HEADER_FIWARE_SERVICEPATH}")

IDS=($(echo "$ENTITIES" | jq -r '.[].id'))
if [[ ${#IDS[@]} -eq 0 ]]; then
  echo "No entities of type '${TYPE_FILTER}' found." >&2
  exit 1
fi

echo ""
echo "Select entity to delete:"
select ENTITY_ID in "${IDS[@]}"; do
  [[ -n "$ENTITY_ID" ]] && break
  echo "Invalid choice."
done

echo ""
echo "DELETE ${ENTITIES_URL}/${ENTITY_ID}"
read -p "Confirm delete? [y/N]: " CONFIRM
[[ "$CONFIRM" =~ ^[yY] ]] || exit 0

HTTP_CODE=$(curl -s -o /tmp/delete_entity_resp -w "%{http_code}" -X DELETE \
  "${ENTITIES_URL}/${ENTITY_ID}" \
  -H "${HEADER_FIWARE_SERVICE}" \
  -H "${HEADER_FIWARE_SERVICEPATH}")

if [[ "$HTTP_CODE" == "204" ]]; then
  echo "OK. Entity ${ENTITY_ID} deleted from Orion."
else
  echo "Failed (HTTP $HTTP_CODE): $(cat /tmp/delete_entity_resp 2>/dev/null)" >&2
  exit 1
fi
