#!/bin/bash
source .env

# Read Odoo configuration from .env, or use default values if not set
ODOO_HOST="${ODOO_HOST:-odoo}"
ODOO_PORT="${ODOO_PORT:-8069}"

ODOO_URL="http://${ODOO_HOST}:${ODOO_PORT}/update_last_seen"

curl -L -X POST "http://${HOST}:${ORION_PORT}/v2/subscriptions" \
-H "Content-Type: application/json" \
-H "${HEADER_FIWARE_SERVICE}" \
-H "${HEADER_FIWARE_SERVICEPATH}" \
--data-raw "{
  \"description\": \"Notify Odoo when display status changes\",
  \"subject\": {
    \"entities\": [
      {	
	      \"idPattern\": \".*\",
        \"type\": \"Signage\"
      },
      {	
	      \"idPattern\": \".*\",
        \"type\": \"NeoPixel\"
      }
    ],
    \"condition\": {
      \"attrs\": [
        \"device_status\"
      ]
    }
  },
  \"notification\": {
    \"http\": {
      \"url\": \"${ODOO_URL}\"
    },
    \"attrs\": [],
    \"attrsFormat\": \"keyValues\"
  }
}"

