#!/bin/bash
set -eu

rmq_network=$(
  jq -n \
    --arg singleton_availability_zone "$pcf_az_1" \
    --arg other_availability_zones "$pcf_az_1,$pcf_az_2,$pcf_az_3" \
    '
    {
      "service_network": {
        "name": "dynamic_services",
      },
      "network": {
        "name": "services",
      },
      "other_availability_zones": ($other_availability_zones | split(",") | map({name: .})),
      "singleton_availability_zone": {
        "name": $singleton_availability_zone
      }
    }
    '
)

rmq_resources=$(
  jq -n \
    --argjson internet_connected $INTERNET_CONNECTED \
    '{
      "rabbitmq-server": {"internet_connected": $internet_connected},
      "rabbitmq-haproxy": {"internet_connected": $internet_connected},
      "rabbitmq-broker": {"internet_connected": $internet_connected},
      "broker-registrar": {"internet_connected": $internet_connected},
      "deregister-and-purge-instances": {"internet_connected": $internet_connected},
      "multitenant-smoke-tests": {"internet_connected": $internet_connected},
      "on-demand-broker-smoke-tests": {"internet_connected": $internet_connected},
      "on-demand-broker": {"internet_connected": $internet_connected},
      "register-on-demand-service-broker": {"internet_connected": $internet_connected},
      "deregister-on-demand-service-broker": {"internet_connected": $internet_connected},
      "delete-all-service-instances": {"internet_connected": $internet_connected},
      "upgrade-all-service-instances": {"internet_connected": $internet_connected},
    }'
)

rmq_properties=$(
  jq -n \
    --arg server_admin_username "$SERVER_ADMIN_USERNAME" \
    --arg server_admin_password "$SERVER_ADMIN_PASSWORD" \
    --arg other_availability_zones "$pcf_az_1,$pcf_az_2,$pcf_az_3" \
    '
    {
      ".rabbitmq-server.server_admin_credentials": {
        "value": {
          "identity": $server_admin_username,
          "password": $server_admin_password
        }
      },
      ".rabbitmq-server.plugins": {
        "value": [
          "rabbitmq_federation",
  				"rabbitmq_federation_management",
  				"rabbitmq_management"
        ]
      },
      ".properties.disk_alarm_threshold": { "value": "mem_relative_1_5" },
      ".properties.syslog_selector": { "value": "disabled" },
      ".properties.on_demand_broker_plan_1_cf_service_access": { "value": "enable" },
      ".properties.on_demand_broker_plan_1_rabbitmq_az_placement": {
        "value": [($other_availability_zones | split(",") | map(.))]
        }
      },
      ".properties.on_demand_broker_plan_1_disk_limit_acknowledgement": { "value": ["acknowledge"] }
    }
    '
)

om-linux \
  --target https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --skip-ssl-validation \
  configure-product \
  --product-name p-rabbitmq \
  --product-properties "$rmq_properties" \
  --product-network "$rmq_network" \
  --product-resources "$rmq_resources"
