#!/bin/bash
# One-time setup: config, Docker network, provision, subscription, start stack, optional systemd

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

# ---- 1. Config ----
if [ ! -f "$ROOT/config/config.env" ]; then
  if [ ! -d "$ROOT/config.example" ]; then
    echo "Error: config.example not found." >&2
    exit 1
  fi
  echo "Creating config/ from config.example..."
  cp -r "$ROOT/config.example" "$ROOT/config"
  echo "  -> config/config.env created."
fi

echo ""
read -p "Edit config/config.env now (ports, Odoo host, etc.)? [y/N]: " EDIT
if [[ "$EDIT" =~ ^[yY] ]]; then
  "${EDITOR:-nano}" "$ROOT/config/config.env"
fi

# ---- 2. Docker network ----
NETWORK_NAME="${PYLON_NETWORK_NAME:-odobundle-codebase_odoo-net}"
echo ""
echo "==> [pylon] Ensuring Docker network '${NETWORK_NAME}' exists..."
if ! docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}\$"; then
  docker network create "${NETWORK_NAME}"
  echo "    Created."
else
  echo "    Already exists."
fi

# ---- 3. Start stack (needed before provision) ----
echo ""
echo "==> [pylon] Starting stack..."
chmod +x "$ROOT/run.sh"
bash "$ROOT/run.sh"

echo "==> [pylon] Waiting for services to boot..."
sleep 5

# ---- 4. One-time: provision + subscription ----
echo ""
echo "==> [pylon] Provisioning IoT Agent service groups..."
bash "$ROOT/ops/provision_service_group.sh"

echo ""
echo "==> [pylon] Registering Orion subscription for Odoo..."
bash "$ROOT/ops/register_subscription.sh"

echo ""
echo "==> [pylon] Setup complete. Stack is running."

# ---- 5. Optional: systemd ----
echo ""
read -p "Install systemd service (start on boot)? [y/N]: " INSTALL_SVC
if [[ "$INSTALL_SVC" =~ ^[yY] ]]; then
  echo "Installing service requires sudo."
  sudo -v
  SVC_FILE="/etc/systemd/system/pylon.service"
  sed "s|@INSTALL_DIR@|$ROOT|g" "$ROOT/ops/systemd/pylon.service" | sudo tee "$SVC_FILE" > /dev/null
  sudo systemctl daemon-reload
  sudo systemctl enable --now pylon
  echo "  -> $SVC_FILE installed and started."
else
  echo "To start manually: ./run.sh"
fi
