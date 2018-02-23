#!/bin/bash
set -eu

scs_network=$(
  jq -n \
    --arg iaas "$pcf_iaas" \
    --arg singleton_availability_zone "$pcf_az_1" \
    --arg other_availability_zones "$pcf_az_1,$pcf_az_2,$pcf_az_3" \
    '
    {
      "singleton_availability_zone": {
    		"name": $singleton_availability_zone
    	},
    	"other_availability_zones": ($other_availability_zones | split(",") | map({name: .})),
      "network": {
        "name": (if $iaas == "aws" then "deployment" else "ert" end),
      }
    }
    '
)

scs_resources=$(
  jq -n \
    --argjson internet_connected $INTERNET_CONNECTED \
    '{
      "deploy-service-broker": {"internet_connected": $internet_connected},
      "register-service-broker": {"internet_connected": $internet_connected},
      "run-smoke-tests": {"internet_connected": $internet_connected},
      "destroy-service-broker": {"internet_connected": $internet_connected}
    }'
)


om-linux \
  --target https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --skip-ssl-validation \
  configure-product \
  --product-name p-spring-cloud-services \
  --product-network "$scs_network" \
  --product-resources "$scs_resources"
