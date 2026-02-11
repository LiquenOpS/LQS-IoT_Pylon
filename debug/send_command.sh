#!/usr/bin/env bash
# Interactive: list devices, pick one, pick command, send to Orion.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/config/config.env}"
[[ -f "${ENV_FILE}" ]] || { echo "Config not found. Run setup.sh first." >&2; exit 1; }
# shellcheck disable=SC1090
source "${ENV_FILE}"

ORION_HOST="${ORION_HOST:-localhost}"
ORION_URL="http://${ORION_HOST}:${ORION_PORT}"
ENTITIES_URL="${ORION_URL}/v2/entities"
ATTRS_URL="${ORION_URL}/v2/entities"

echo "Fetching Yardmaster entities..."
ENTITIES=$(curl -s -L -X GET "${ENTITIES_URL}?type=Yardmaster" \
  -H "${HEADER_FIWARE_SERVICE}" \
  -H "${HEADER_FIWARE_SERVICEPATH}")

IDS=($(echo "$ENTITIES" | jq -r '.[].id'))
if [[ ${#IDS[@]} -eq 0 ]]; then
  echo "No Yardmaster entities found. Provision and send heartbeat first." >&2
  exit 1
fi

echo ""
echo "Select device:"
select ENTITY_ID in "${IDS[@]}"; do
  [[ -n "$ENTITY_ID" ]] && break
  echo "Invalid choice."
done

echo ""
echo "LEDStrip commands:"
echo "  1) effectSet off    - Turn off LEDs"
echo "  2) effectSet rainbow"
echo "  3) ledConfig        - Custom JSON (e.g. {\"runtime\":{\"effects_playlist\":[\"off\"]}})"
echo "  4) playlistResume"
echo "  5) playlistAdd      - Add effect to playlist"
echo "  6) playlistRemove   - Remove from playlist"
echo ""
read -p "Choice [1-6]: " CMD_CHOICE

build_payload() {
  case "$CMD_CHOICE" in
    1) echo '{"effectSet":{"type":"command","value":{"effect":"off"}}}' ;;
    2) echo '{"effectSet":{"type":"command","value":{"effect":"rainbow"}}}' ;;
    3)
      read -p "ledConfig JSON value: " LED_JSON
      echo "{\"ledConfig\":{\"type\":\"command\",\"value\":${LED_JSON}}}"
      ;;
    4) echo '{"playlistResume":{"type":"command","value":{}}}' ;;
    5)
      read -p "Effect name (e.g. fire, waterfall): " EFF
      echo "{\"playlistAdd\":{\"type\":\"command\",\"value\":{\"effect\":\"${EFF}\"}}}"
      ;;
    6)
      read -p "Effect name to remove: " EFF
      echo "{\"playlistRemove\":{\"type\":\"command\",\"value\":{\"effect\":\"${EFF}\"}}}"
      ;;
    *)
      echo "Invalid choice." >&2
      exit 1
      ;;
  esac
}

PAYLOAD=$(build_payload)
echo ""
echo "PATCH ${ATTRS_URL}/${ENTITY_ID}/attrs?type=Yardmaster"
echo "Payload: $PAYLOAD"
read -p "Send? [y/N]: " CONFIRM
[[ "$CONFIRM" =~ ^[yY] ]] || exit 0

HTTP_CODE=$(curl -s -o /tmp/send_cmd_resp -w "%{http_code}" -X PATCH \
  "${ATTRS_URL}/${ENTITY_ID}/attrs?type=Yardmaster" \
  -H "Content-Type: application/json" \
  -H "${HEADER_FIWARE_SERVICE}" \
  -H "${HEADER_FIWARE_SERVICEPATH}" \
  -d "$PAYLOAD")

if [[ "$HTTP_CODE" =~ ^(200|204)$ ]]; then
  echo "OK (HTTP $HTTP_CODE). Command sent. Check Yardmaster/Glimmer."
else
  echo "Failed (HTTP $HTTP_CODE): $(cat /tmp/send_cmd_resp 2>/dev/null)" >&2
  exit 1
fi
