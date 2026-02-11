#!/bin/bash
# Interactive setup. Choose what to run; no parameters.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

echo ""
echo "Pylon setup — what would you like to do?"
echo "  1) Install essentials (config, network, start stack)"
echo "  2) Provision (service groups + subscription)"
echo "  3) Install systemd (start on boot)"
echo "  4) Uninstall (stop stack, remove systemd)"
echo "  5) Exit"
echo ""
read -p "Choice [1-5]: " CHOICE

case "$CHOICE" in
  1)
    # ---- Config ----
    if [ ! -f "$ROOT/config/config.env" ]; then
      [ ! -d "$ROOT/config.example" ] && { echo "Error: config.example not found." >&2; exit 1; }
      echo "Creating config/ from config.example..."
      cp -r "$ROOT/config.example" "$ROOT/config"
      echo "  -> config/config.env created."
    fi

    echo ""
    echo "Which part to run on this host?"
    echo "  n) North only (Orion + MongoDB, Intranet)"
    echo "  s) South only (IoT Agent, device-facing)"
    echo "  f) Full-stack (both on this host)"
    echo ""
    read -p "Choice [n/s/f]: " PART
    case "$PART" in
      n) PYLON_MODE=north ;;
      s) PYLON_MODE=south ;;
      f) PYLON_MODE=full ;;
      *) echo "Invalid. Using full-stack."; PYLON_MODE=full ;;
    esac
    grep -q "^PYLON_MODE=" "$ROOT/config/config.env" 2>/dev/null \
      && sed -i "s/^PYLON_MODE=.*/PYLON_MODE=${PYLON_MODE}/" "$ROOT/config/config.env" \
      || echo "PYLON_MODE=${PYLON_MODE}" >> "$ROOT/config/config.env"

    echo "  See config.example and docs/LQS-IoT_PYLON_DEPLOYMENT_MODES.md for ODOO_HOST, IOTA_* per scenario."
    read -p "Edit config/config.env now? [y/N]: " EDIT
    [[ "$EDIT" =~ ^[yY] ]] && "${EDITOR:-vi}" "$ROOT/config/config.env"

    # ---- Docker network ----
    set -a && source "$ROOT/config/config.env" && set +a
    NETWORK_NAME="${PYLON_NETWORK_NAME:-pylon-net}"
    echo ""
    echo "==> Ensuring Docker network '${NETWORK_NAME}' exists..."
    if ! docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}\$"; then
      docker network create "${NETWORK_NAME}"
      echo "    Created."
    else
      echo "    Already exists."
    fi

    # ---- Start stack ----
    echo ""
    echo "==> Starting Pylon (${PYLON_MODE})..."
    chmod +x "$ROOT/run.sh"
    bash "$ROOT/run.sh" --mode "$PYLON_MODE"
    echo "==> Stack is running. Use option 2 to provision (run on host where South/IOTA runs)."
    ;;
  2)
    [ ! -f "$ROOT/config/config.env" ] && { echo "Error: config/config.env not found. Run option 1 first." >&2; exit 1; }
    set -a && source "$ROOT/config/config.env" && set +a
    echo ""
    echo "==> Provisioning service groups (POST to IOTA)..."
    bash "$ROOT/ops/provision_service_group.sh"
    echo ""
    echo "==> Registering Orion subscription (POST to Orion)..."
    bash "$ROOT/ops/register_subscription.sh"
    echo "Done."
    ;;
  3)
    read -p "Install systemd service (start on boot)? [y/N]: " Y
    if [[ "$Y" =~ ^[yY] ]]; then
      [ ! -f "$ROOT/config/config.env" ] && { echo "Error: config/config.env not found. Run option 1 first." >&2; exit 1; }
      set -a && source "$ROOT/config/config.env" && set +a
      MODE="${PYLON_MODE:-full}"
      sudo -v
      SVC_FILE="/etc/systemd/system/pylon.service"
      sed "s|@INSTALL_DIR@|$ROOT|g" \
        "$ROOT/ops/systemd/pylon.service" | sudo tee "$SVC_FILE" > /dev/null
      sudo systemctl daemon-reload
      sudo systemctl enable --now pylon
      echo "  -> $SVC_FILE installed and started (mode=${MODE})."
    fi
    ;;
  4)
    echo "==> Uninstalling Pylon..."
    SVC_FILE="/etc/systemd/system/pylon.service"
    if [ -f "$SVC_FILE" ]; then
      sudo -v
      sudo systemctl stop pylon 2>/dev/null || true
      sudo systemctl disable pylon 2>/dev/null || true
      sudo rm -f "$SVC_FILE"
      sudo systemctl daemon-reload
      echo "  -> systemd service removed."
    fi
    if [ -f "$ROOT/config/config.env" ]; then
      set -a && source "$ROOT/config/config.env" && set +a
      MODE="${PYLON_MODE:-full}"
      echo "  -> Stopping Docker stack (${MODE})..."
      case "$MODE" in
        north) docker compose --env-file "$ROOT/config/config.env" -f "$ROOT/docker-compose.north.yml" down ;;
        south) docker compose --env-file "$ROOT/config/config.env" -f "$ROOT/docker-compose.south.yml" down ;;
        full)
          docker compose --env-file "$ROOT/config/config.env" \
            -f "$ROOT/docker-compose.north.yml" -f "$ROOT/docker-compose.south.yml" down
          ;;
      esac
    fi
    read -p "Remove config/ and Docker volumes? [y/N]: " Y
    if [[ "$Y" =~ ^[yY] ]]; then
      [ -f "$ROOT/config/config.env" ] && {
        set -a && source "$ROOT/config/config.env" && set +a
        MODE="${PYLON_MODE:-full}"
        case "$MODE" in
          north) docker compose --env-file "$ROOT/config/config.env" -f "$ROOT/docker-compose.north.yml" down -v 2>/dev/null || true ;;
          south) docker compose --env-file "$ROOT/config/config.env" -f "$ROOT/docker-compose.south.yml" down 2>/dev/null || true ;;
          full)  docker compose --env-file "$ROOT/config/config.env" -f "$ROOT/docker-compose.north.yml" -f "$ROOT/docker-compose.south.yml" down -v 2>/dev/null || true ;;
        esac
      }
      rm -rf "$ROOT/config"
      echo "  -> config and volumes removed."
    fi
    echo "Done."
    ;;
  5)
    echo "Bye."
    ;;
  *)
    echo "Invalid choice."
    exit 1
    ;;
esac
