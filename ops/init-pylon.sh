#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

NETWORK_NAME="${PYLON_NETWORK_NAME:-odobundle-codebase_odoo-net}"

echo "==> [pylon] Ensuring Docker network '${NETWORK_NAME}' exists..."
if ! docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}\$"; then
  docker network create "${NETWORK_NAME}"
  echo "    Created network '${NETWORK_NAME}'."
else
  echo "    Network '${NETWORK_NAME}' already exists."
fi

ENV_FILE="${ROOT_DIR}/config/config.env"
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Error: config/config.env not found. Copy config.example to config first." >&2
  exit 1
fi
echo "==> [pylon] Starting core FIWARE stack (Orion + IoT Agent + MongoDB)..."
docker compose --env-file "${ENV_FILE}" up -d

echo "==> [pylon] Waiting a few seconds for services to boot..."
sleep 5

echo "==> [pylon] Provisioning IoT Agent service groups..."
"${ROOT_DIR}/ops/provision_service_group.sh"

echo "==> [pylon] Registering Orion subscription for Odoo..."
"${ROOT_DIR}/ops/register_subscription.sh"

echo "==> [pylon] Done. LQS-IoT_Pylon core is up."

