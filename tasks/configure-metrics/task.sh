#!/bin/bash
set -eu

export OPSMAN_DOMAIN_OR_IP_ADDRESS="opsman.$pcf_ert_domain"

metrics_network=$(
  jq -n \
    --arg iaas $pcf_iaas \
    --arg singleton_availability_zone "$pcf_az_1" \
    --arg other_availability_zones "$pcf_az_1,$pcf_az_2,$pcf_az_3" \
    '
    {
      "network": {
        "name": (if $iaas == "aws" then "deployment" else "ert" end),
      },
      "other_availability_zones": ($other_availability_zones | split(",") | map({name: .})),
      "singleton_availability_zone": {
        "name": $singleton_availability_zone
      }
    }
    '
)

metrics_resources=$(
  jq -n \
    '
    {
      "maximus": {"internet_connected": false},
      "jmx-firehose-nozzle": {"internet_connected": false},
      "integration-tests": {"internet_connected": false}
    }
    '
)

metrics_properties=$(
  jq -n \
    --arg metrics_admin_id $metrics_admin_id \
    --arg metrics_admin_password "$metrics_admin_password" \
    '
    {
      ".maximus.credentials": {
        "value": {
          "identity": $metrics_admin_id,
          "password": $metrics_admin_password
        }
      }
    }
    '
)

om-linux \
  --target https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
  --username $OPS_MGR_USR \
  --password $OPS_MGR_PWD \
  --skip-ssl-validation \
  configure-product \
  --product-name p-metrics \
  --product-properties "$metrics_properties" \
  --product-network "$metrics_network" \
  --product-resources "$metrics_resources"
