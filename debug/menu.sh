#!/usr/bin/env bash
# Pylon debug menu - all-in-one interactive. No args.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/config/config.env}"
[[ -f "${ENV_FILE}" ]] || { echo "Config not found. Run setup.sh first." >&2; exit 1; }
# shellcheck disable=SC1090
source "${ENV_FILE}"

ORION_HOST="${ORION_HOST:-localhost}"
IOTA_HOST="${IOTA_HOST:-localhost}"
ORION_URL="http://${ORION_HOST}:${ORION_PORT}"
ENTITIES_URL="${ORION_URL}/v2/entities"
SUB_URL="${ORION_URL}/v2/subscriptions"

# -----------------------------------------------------------------------------
# List
# -----------------------------------------------------------------------------
do_list() {
  echo ""
  echo "List what?"
  echo "  1) Orion entities"
  echo "  2) Orion subscriptions"
  echo "  3) IOTA devices"
  echo "  4) IOTA service groups"
  read -p "Choice [1-4]: " C
  case "$C" in
    1)
      echo ""
      echo "Entity type filter?"
      echo "  1) All"
      echo "  2) LEDStrip"
      echo "  3) Signage"
      read -p "Choice [1-3]: " T
      URL="${ENTITIES_URL}"
      case "$T" in
        2) URL="${URL}?type=LEDStrip" ;;
        3) URL="${URL}?type=Signage" ;;
      esac
      echo "Orion entities..."
      curl -s -L -X GET "$URL" -H "${HEADER_FIWARE_SERVICE}" -H "${HEADER_FIWARE_SERVICEPATH}" | jq .
      ;;
    2)
      echo "Orion subscriptions..."
      curl -s -L -X GET "$SUB_URL" -H "${HEADER_FIWARE_SERVICE}" -H "${HEADER_FIWARE_SERVICEPATH}" | jq .
      ;;
    3)
      echo "IOTA devices..."
      curl -s -L -X GET "http://${IOTA_HOST}:${IOTA_NORTH_PORT}/iot/devices" \
        -H "${HEADER_FIWARE_SERVICE}" -H "${HEADER_FIWARE_SERVICEPATH}" | jq .
      ;;
    4)
      echo "IOTA service groups..."
      curl -s -L -X GET "http://${IOTA_HOST}:${IOTA_NORTH_PORT}/iot/services" \
        -H "${HEADER_FIWARE_SERVICE}" -H "${HEADER_FIWARE_SERVICEPATH}" | jq .
      ;;
    *) echo "Invalid." ;;
  esac
}

# -----------------------------------------------------------------------------
# Delete entity
# -----------------------------------------------------------------------------
do_delete_entity() {
  echo ""
  echo "Entity type?"
  echo "  1) LEDStrip"
  echo "  2) Signage"
  read -p "Choice [1-2]: " T
  case "$T" in
    2) ENTITY_TYPE="Signage" ;;
    *) ENTITY_TYPE="LEDStrip" ;;
  esac

  ENTITIES=$(curl -s -L -X GET "${ENTITIES_URL}?type=${ENTITY_TYPE}" \
    -H "${HEADER_FIWARE_SERVICE}" -H "${HEADER_FIWARE_SERVICEPATH}")
  IDS=($(echo "$ENTITIES" | jq -r '.[].id'))
  if [[ ${#IDS[@]} -eq 0 ]]; then
    echo "No ${ENTITY_TYPE} entities found." >&2
    return
  fi

  echo ""
  echo "Select entity to delete:"
  select ENTITY_ID in "${IDS[@]}"; do
    [[ -n "$ENTITY_ID" ]] && break
    echo "Invalid choice."
  done

  read -p "Confirm delete ${ENTITY_ID}? [y/N]: " CONFIRM
  [[ "$CONFIRM" =~ ^[yY] ]] || return

  HTTP_CODE=$(curl -s -o /tmp/del_resp -w "%{http_code}" -X DELETE \
    "${ENTITIES_URL}/${ENTITY_ID}" -H "${HEADER_FIWARE_SERVICE}" -H "${HEADER_FIWARE_SERVICEPATH}")
  if [[ "$HTTP_CODE" == "204" ]]; then
    echo "Deleted ${ENTITY_ID}"
  else
    echo "Failed (HTTP $HTTP_CODE): $(cat /tmp/del_resp 2>/dev/null)" >&2
  fi
}

# -----------------------------------------------------------------------------
# Delete subscription
# -----------------------------------------------------------------------------
do_delete_subscription() {
  SUBS=$(curl -s -L -X GET "$SUB_URL" -H "${HEADER_FIWARE_SERVICE}" -H "${HEADER_FIWARE_SERVICEPATH}")

  echo ""
  echo "Filter by entity type?"
  echo "  1) All"
  echo "  2) LEDStrip"
  echo "  3) Signage"
  echo "  4) Yardmaster (legacy)"
  read -p "Choice [1-4]: " T
  case "$T" in
    2) TYPE_FILTER="LEDStrip" ;;
    3) TYPE_FILTER="Signage" ;;
    4) TYPE_FILTER="Yardmaster" ;;
    *) TYPE_FILTER="" ;;
  esac

  echo ""
  if [[ -n "$TYPE_FILTER" ]]; then
    IDS=($(echo "$SUBS" | jq -r --arg t "$TYPE_FILTER" '.[] | select(.subject.entities[]? | .type == $t) | .id'))
  else
    IDS=($(echo "$SUBS" | jq -r '.[].id'))
  fi

  if [[ ${#IDS[@]} -eq 0 ]]; then
    echo "No subscriptions found." >&2
    return
  fi

  echo "Select subscription to delete:"
  select SUB_ID in "${IDS[@]}"; do
    [[ -n "$SUB_ID" ]] && break
    echo "Invalid choice."
  done

  read -p "Confirm delete ${SUB_ID}? [y/N]: " CONFIRM
  [[ "$CONFIRM" =~ ^[yY] ]] || return

  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -L -X DELETE "${SUB_URL}/${SUB_ID}" \
    -H "${HEADER_FIWARE_SERVICE}" -H "${HEADER_FIWARE_SERVICEPATH}")
  if [[ "$HTTP_CODE" == "204" ]]; then
    echo "Deleted ${SUB_ID}"
  else
    echo "Failed (HTTP $HTTP_CODE)" >&2
  fi
}

# -----------------------------------------------------------------------------
# Send command
# -----------------------------------------------------------------------------
do_send_command() {
  echo ""
  echo "Entity type?"
  echo "  1) LEDStrip (Glimmer)"
  echo "  2) Signage (Anthias)"
  read -p "Choice [1-2]: " T
  case "$T" in
    2) ENTITY_TYPE="Signage" ;;
    *) ENTITY_TYPE="LEDStrip" ;;
  esac

  ENTITIES=$(curl -s -L -X GET "${ENTITIES_URL}?type=${ENTITY_TYPE}" \
    -H "${HEADER_FIWARE_SERVICE}" -H "${HEADER_FIWARE_SERVICEPATH}")
  IDS=($(echo "$ENTITIES" | jq -r '.[].id'))
  if [[ ${#IDS[@]} -eq 0 ]]; then
    echo "No ${ENTITY_TYPE} entities found." >&2
    return
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
    echo "  1) listAssets   2) createAsset  3) deleteAsset"
    echo "  4) updatePlaylistOrder  5) updateAssetPatch"
    echo "  6) setAdopted true  7) setAdopted false"
    read -p "Choice [1-7]: " CMD
    case "$CMD" in
      1) PAYLOAD='{"listAssets":{"type":"command","value":{}}}' ;;
      2) read -p "createAsset JSON: " J; PAYLOAD="{\"createAsset\":{\"type\":\"command\",\"value\":${J}}}" ;;
      3) read -p "Asset ID: " AID; PAYLOAD="{\"deleteAsset\":{\"type\":\"command\",\"value\":{\"id\":\"${AID}\"}}}" ;;
      4) read -p "updatePlaylistOrder JSON: " J; PAYLOAD="{\"updatePlaylistOrder\":{\"type\":\"command\",\"value\":${J}}}" ;;
      5) read -p "updateAssetPatch JSON: " J; PAYLOAD="{\"updateAssetPatch\":{\"type\":\"command\",\"value\":${J}}}" ;;
      6) PAYLOAD='{"setAdopted":{"type":"command","value":true}}' ;;
      7) PAYLOAD='{"setAdopted":{"type":"command","value":false}}' ;;
      *) echo "Invalid."; return ;;
    esac
  else
    echo "LEDStrip commands:"
    echo "  1) effectSet off  2) effectSet rainbow  3) ledConfig"
    echo "  4) playlistResume  5) playlistAdd  6) playlistRemove"
    echo "  7) setAdopted true  8) setAdopted false"
    read -p "Choice [1-8]: " CMD
    case "$CMD" in
      1) PAYLOAD='{"effectSet":{"type":"command","value":{"effect":"off"}}}' ;;
      2) PAYLOAD='{"effectSet":{"type":"command","value":{"effect":"rainbow"}}}' ;;
      3) read -p "ledConfig JSON: " J; PAYLOAD="{\"ledConfig\":{\"type\":\"command\",\"value\":${J}}}" ;;
      4) PAYLOAD='{"playlistResume":{"type":"command","value":{}}}' ;;
      5) read -p "Effect name: " E; PAYLOAD="{\"playlistAdd\":{\"type\":\"command\",\"value\":{\"effect\":\"${E}\"}}}" ;;
      6) read -p "Effect to remove: " E; PAYLOAD="{\"playlistRemove\":{\"type\":\"command\",\"value\":{\"effect\":\"${E}\"}}}" ;;
      7) PAYLOAD='{"setAdopted":{"type":"command","value":true}}' ;;
      8) PAYLOAD='{"setAdopted":{"type":"command","value":false}}' ;;
      *) echo "Invalid."; return ;;
    esac
  fi

  echo ""
  echo "PATCH ${ENTITY_ID} (type=${ENTITY_TYPE})"
  echo "Payload: $PAYLOAD"
  read -p "Send? [Y/n]: " CONFIRM
  [[ "$CONFIRM" =~ ^[nN]$ ]] && return

  HTTP_CODE=$(curl -s -o /tmp/send_resp -w "%{http_code}" -X PATCH \
    "${ENTITIES_URL}/${ENTITY_ID}/attrs?type=${ENTITY_TYPE}" \
    -H "Content-Type: application/json" -H "${HEADER_FIWARE_SERVICE}" -H "${HEADER_FIWARE_SERVICEPATH}" \
    -d "$PAYLOAD")
  if [[ "$HTTP_CODE" =~ ^(200|204)$ ]]; then
    echo "OK. Command sent."
  else
    echo "Failed (HTTP $HTTP_CODE): $(cat /tmp/send_resp 2>/dev/null)" >&2
  fi
}

# -----------------------------------------------------------------------------
# Main loop
# -----------------------------------------------------------------------------
while true; do
  echo ""
  echo "Pylon debug menu"
  echo "  1) List (entities / subscriptions / devices / services)"
  echo "  2) Delete entity"
  echo "  3) Delete subscription"
  echo "  4) Send command"
  echo "  5) Exit"
  read -p "Choice [1-5]: " C

  case "$C" in
    1) do_list ;;
    2) do_delete_entity ;;
    3) do_delete_subscription ;;
    4) do_send_command ;;
    5) echo "Bye."; exit 0 ;;
    *) echo "Invalid." ;;
  esac
done
