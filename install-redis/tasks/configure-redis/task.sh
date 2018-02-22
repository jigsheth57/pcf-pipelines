#!/bin/bash
set -eu

redis_network=$(
  jq -n \
    --arg singleton_availability_zone "$pcf_az_1" \
    --arg other_availability_zones "$pcf_az_1,$pcf_az_2,$pcf_az_3" \
    '
    {
      "singleton_availability_zone": {
    		"name": $singleton_availability_zone
    	},
    	"other_availability_zones": ($other_availability_zones | split(",") | map({name: .})),
    	"network": {
    		"name": "services"
    	},
    	"service_network": {
    		"name": "dynamic-services"
    	}
    }
    '
)

redis_resources=$(
  jq -n \
    --arg redis_tile "$TILE_INSTALL" \
    --argjson internet_connected $INTERNET_CONNECTED \
    '{
      "redis-on-demand-broker": {"internet_connected": $internet_connected},
      "register-broker": {"internet_connected": $internet_connected},
      "upgrade-all-service-instances": {"internet_connected": $internet_connected},
      "delete-all-service-instances-and-deregister-broker": {"internet_connected": $internet_connected},
      "on-demand-broker-smoke-tests": {"internet_connected": $internet_connected},
      "cf-redis-broker": {"internet_connected": $internet_connected},
      "dedicated-node": {
        "instances": (if $redis_tile == "minimum" then 1 else "" end),
        "internet_connected": $internet_connected
      },
      "broker-registrar": {"internet_connected": $internet_connected},
      "broker-deregistrar": {"internet_connected": $internet_connected},
      "smoke-tests": {"internet_connected": $internet_connected}
    }'
)

redis_properties=$(
  jq -n \
    --arg singleton_availability_zone "$pcf_az_1" \
    '
    {
      ".properties.small_plan_selector.active.az_single_select": { "value": $singleton_availability_zone },
      ".properties.small_plan_selector.active.lua_scripting": { "value": true },
      ".properties.medium_plan_selector": { "value": "Plan Inactive" },
      ".properties.large_plan_selector": { "value": "Plan Inactive" },
      ".properties.syslog_selector": { "value": "No" }
    }
    '
)

om-linux \
  --target https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --skip-ssl-validation \
  configure-product \
  --product-name p-redis \
  --product-properties "$redis_properties" \
  --product-network "$redis_network" \
  --product-resources "$redis_resources"
