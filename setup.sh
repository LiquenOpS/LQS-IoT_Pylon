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
    read -p "Edit config/config.env now (ports, Odoo host, etc.)? [y/N]: " EDIT
    [[ "$EDIT" =~ ^[yY] ]] && "${EDITOR:-vi}" "$ROOT/config/config.env"

    # ---- Docker network ----
    [ -f "$ROOT/config/config.env" ] && set -a && source "$ROOT/config/config.env" && set +a
    NETWORK_NAME="${PYLON_NETWORK_NAME:-odobundle-codebase_odoo-net}"
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
    echo "==> Starting stack..."
    chmod +x "$ROOT/run.sh"
    bash "$ROOT/run.sh"
    echo "==> Stack is running. Use option 2 to provision."
    ;;
  2)
    [ ! -f "$ROOT/config/config.env" ] && { echo "Error: config/config.env not found. Run option 1 first." >&2; exit 1; }
    set -a && source "$ROOT/config/config.env" && set +a
    echo ""
    echo "==> Provisioning service groups..."
    bash "$ROOT/ops/provision_service_group.sh"
    echo ""
    echo "==> Registering Orion subscription..."
    bash "$ROOT/ops/register_subscription.sh"
    echo "Done."
    ;;
  3)
    read -p "Install systemd service (start on boot)? [y/N]: " Y
    if [[ "$Y" =~ ^[yY] ]]; then
      sudo -v
      SVC_FILE="/etc/systemd/system/pylon.service"
      sed "s|@INSTALL_DIR@|$ROOT|g" "$ROOT/ops/systemd/pylon.service" | sudo tee "$SVC_FILE" > /dev/null
      sudo systemctl daemon-reload
      sudo systemctl enable --now pylon
      echo "  -> $SVC_FILE installed and started."
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
      echo "  -> Stopping Docker stack..."
      docker compose --env-file "$ROOT/config/config.env" -f "$ROOT/docker-compose.yml" down
    fi
    read -p "Remove config/ and Docker volumes? [y/N]: " Y
    if [[ "$Y" =~ ^[yY] ]]; then
      [ -f "$ROOT/config/config.env" ] && docker compose --env-file "$ROOT/config/config.env" -f "$ROOT/docker-compose.yml" down -v 2>/dev/null || true
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
