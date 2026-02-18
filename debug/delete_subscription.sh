#!/usr/bin/env bash
# Delete Orion subscription by ID.
# Usage: ./delete_subscription.sh [subscription_id]
#   With no arg: list subscriptions (optionally filter by entity type), prompt for ID.

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

ORION_HOST="${ORION_HOST:-localhost}"
SUB_URL="http://${ORION_HOST}:${ORION_PORT}/v2/subscriptions"

SUB_ID="${1:-}"
if [[ -z "$SUB_ID" ]]; then
  SUBS=$(curl -s -L -X GET "$SUB_URL" \
    -H "${HEADER_FIWARE_SERVICE}" \
    -H "${HEADER_FIWARE_SERVICEPATH}")

  echo "Filter by entity type?"
  echo "  1) All"
  echo "  2) LEDStrip"
  echo "  3) Signage"
  echo "  4) Yardmaster (legacy)"
  read -p "Choice [1-4]: " TYPE_CHOICE
  case "$TYPE_CHOICE" in
    2) TYPE_FILTER="LEDStrip" ;;
    3) TYPE_FILTER="Signage" ;;
    4) TYPE_FILTER="Yardmaster" ;;
    *) TYPE_FILTER="" ;;
  esac

  echo ""
  echo "Orion subscriptions for ${FIWARE_SERVICE}:"
  if [[ -n "$TYPE_FILTER" ]]; then
    echo "$SUBS" | jq -r --arg t "$TYPE_FILTER" '
      .[] | select(.subject.entities[]? | .type == $t) | "\(.id)  \(.description) (type=\(.subject.entities[0].type))"
    '
  else
    echo "$SUBS" | jq -r '.[] | "\(.id)  \(.description) (types: \([.subject.entities[]?.type] | join(",")))"'
  fi
  echo ""
  read -p "Subscription ID to delete: " SUB_ID
  [[ -z "$SUB_ID" ]] && { echo "Aborted." >&2; exit 1; }
fi

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -L -X DELETE "${SUB_URL}/${SUB_ID}" \
  -H "${HEADER_FIWARE_SERVICE}" \
  -H "${HEADER_FIWARE_SERVICEPATH}")

if [[ "$HTTP_CODE" == "204" ]]; then
  echo "Deleted subscription ${SUB_ID}"
else
  echo "Delete failed: HTTP ${HTTP_CODE}" >&2
  exit 1
fi
