#!/usr/bin/env bash
# Interactive: select type, list devices, pick one, pick command, send to Orion.

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

echo "Entity type:"
echo "  1) LEDStrip (Glimmer)"
echo "  2) Signage (Anthias)"
read -p "Choice [1/2]: " TYPE_CHOICE
case "$TYPE_CHOICE" in
  2) ENTITY_TYPE="Signage" ;;
  *) ENTITY_TYPE="LEDStrip" ;;
esac

echo ""
echo "Fetching ${ENTITY_TYPE} entities..."
ENTITIES=$(curl -s -L -X GET "${ENTITIES_URL}?type=${ENTITY_TYPE}" \
  -H "${HEADER_FIWARE_SERVICE}" \
  -H "${HEADER_FIWARE_SERVICEPATH}")

IDS=($(echo "$ENTITIES" | jq -r '.[].id'))
if [[ ${#IDS[@]} -eq 0 ]]; then
  echo "No ${ENTITY_TYPE} entities found. Provision and send heartbeat first." >&2
  exit 1
fi

echo ""
echo "Select device:"
select ENTITY_ID in "${IDS[@]}"; do
  [[ -n "$ENTITY_ID" ]] && break
  echo "Invalid choice."
done

echo ""
if [[ "$ENTITY_TYPE" == "Signage" ]]; then
  echo "Signage commands:"
  echo "  1) listAssets       - List assets"
  echo "  2) createAsset      - Create asset (JSON)"
  echo "  3) deleteAsset      - Delete asset"
  echo "  4) updatePlaylistOrder - Update order"
  echo "  5) updateAssetPatch - Patch asset"
  echo "  6) setAdopted true  - Mark adopted"
  echo "  7) setAdopted false - Mark unadopted"
  echo ""
  read -p "Choice [1-7]: " CMD_CHOICE
  build_payload() {
    case "$CMD_CHOICE" in
      1) echo '{"listAssets":{"type":"command","value":{}}}' ;;
      2)
        read -p "createAsset JSON value: " JSON_VAL
        echo "{\"createAsset\":{\"type\":\"command\",\"value\":${JSON_VAL}}}"
        ;;
      3)
        read -p "Asset ID to delete: " AID
        echo "{\"deleteAsset\":{\"type\":\"command\",\"value\":{\"id\":\"${AID}\"}}}"
        ;;
      4)
        read -p "updatePlaylistOrder JSON (e.g. {\"order\":[\"a\",\"b\"]}): " JSON_VAL
        echo "{\"updatePlaylistOrder\":{\"type\":\"command\",\"value\":${JSON_VAL}}}"
        ;;
      5)
        read -p "updateAssetPatch JSON (id + patch): " JSON_VAL
        echo "{\"updateAssetPatch\":{\"type\":\"command\",\"value\":${JSON_VAL}}}"
        ;;
      6) echo '{"setAdopted":{"type":"command","value":true}}' ;;
      7) echo '{"setAdopted":{"type":"command","value":false}}' ;;
      *)
        echo "Invalid choice." >&2
        exit 1
        ;;
    esac
  }
else
  echo "LEDStrip commands:"
  echo "  1) effectSet off    - Turn off LEDs"
  echo "  2) effectSet rainbow"
  echo "  3) ledConfig        - Custom JSON (e.g. {\"runtime\":{\"effects_playlist\":[\"off\"]}})"
  echo "  4) playlistResume"
  echo "  5) playlistAdd      - Add effect to playlist"
  echo "  6) playlistRemove   - Remove from playlist"
  echo "  7) setAdopted true  - Mark device adopted (fetches supportedEffects)"
  echo "  8) setAdopted false - Mark device unadopted"
  echo ""
  read -p "Choice [1-8]: " CMD_CHOICE
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
      7) echo '{"setAdopted":{"type":"command","value":true}}' ;;
      8) echo '{"setAdopted":{"type":"command","value":false}}' ;;
      *)
        echo "Invalid choice." >&2
        exit 1
        ;;
    esac
  }
fi

PAYLOAD=$(build_payload)
echo ""
echo "PATCH ${ATTRS_URL}/${ENTITY_ID}/attrs?type=${ENTITY_TYPE}"
echo "Payload: $PAYLOAD"
read -p "Send? [Y/n]: " CONFIRM
[[ "$CONFIRM" =~ ^[nN]$ ]] && exit 0

HTTP_CODE=$(curl -s -o /tmp/send_cmd_resp -w "%{http_code}" -X PATCH \
  "${ATTRS_URL}/${ENTITY_ID}/attrs?type=${ENTITY_TYPE}" \
  -H "Content-Type: application/json" \
  -H "${HEADER_FIWARE_SERVICE}" \
  -H "${HEADER_FIWARE_SERVICEPATH}" \
  -d "$PAYLOAD")

if [[ "$HTTP_CODE" =~ ^(200|204)$ ]]; then
  echo "OK (HTTP $HTTP_CODE). Command sent. Check Yardmaster."
else
  echo "Failed (HTTP $HTTP_CODE): $(cat /tmp/send_cmd_resp 2>/dev/null)" >&2
  exit 1
fi
