#!/bin/bash
source .env
ORION_HOST="${ORION_HOST:-orion}"
ORION_PORT="${ORION_PORT:-1026}"

ORION_BROKER="http://${ORION_HOST}:${ORION_PORT}"

echo "Provisioning IoT Agent with a Service Group..."
echo "----------------------------------------------"

curl -s -o /dev/null -w "%{http_code}" -L -X POST "http://${IOTA_HOST}:${IOTA_NORTH_PORT}/iot/services" \
-H "${HEADER_CONTENT_TYPE}" \
-H "${HEADER_FIWARE_SERVICE}" \
-H "${HEADER_FIWARE_SERVICEPATH}" \
--data-raw "{
    \"services\": [
        {
            \"apikey\": \"SignKey\",
            \"cbroker\": \"${ORION_BROKER}\",
            \"entity_type\": \"Signage\",
            \"resource\": \"/iot/json\"
        },
        {
            \"apikey\": \"SignKeyForNeoPixel\",
            \"cbroker\": \"${ORION_BROKER}\",
            \"entity_type\": \"NeoPixel\",
            \"resource\": \"/iot/json\"
        }
    ]
}"

echo -e "\nDone. If status code is 201, the service group was created successfully."
