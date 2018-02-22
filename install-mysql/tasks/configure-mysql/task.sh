#!/bin/bash
set -eu

mysql_network=$(
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

mysql_resources=$(
  jq -n \
    --argjson internet_connected $INTERNET_CONNECTED \
    '{
      "dedicated-mysql-broker": {"internet_connected": $internet_connected},
      "register-broker": {"internet_connected": $internet_connected},
      "smoke-tests": {"internet_connected": $internet_connected},
      "delete-all-service-instances-and-deregister-broker": {"internet_connected": $internet_connected},
      "upgrade-all-service-instances": {"internet_connected": $internet_connected},
      "orphan-deployments": {"internet_connected": $internet_connected}
    }'
)

mysql_properties=$(
  jq -n \
    --arg aws_access_key_id "$AWS_ACCESS_KEY_ID" \
    --arg aws_secret_access_key "$AWS_SECRET_ACCESS_KEY" \
    --arg aws_s3_bucket "$S3_BUCKET_BACKUP" \
    --arg aws_s3_bucket_region "$S3_BUCKET_BACKUP_REGION" \
    --arg aws_s3_bucket_path "$S3_BUCKET_BACKUP_PATH" \
    --arg aws_s3_bucket_schedule "$S3_BUCKET_BACKUP_SCHEDULE" \
    --arg other_availability_zones "$pcf_az_1,$pcf_az_2,$pcf_az_3" \
    '
    {
      ".properties.plan1_selector.active.multi_node_deployment": { "value": true },
      ".properties.plan1_selector.active.az_multi_select": {
        "value": ($other_availability_zones | split(",") | map(.))
      },
      ".properties.plan1_selector.active.instance_limit": { "value": 10 },
      ".properties.plan2_selector": { "value": "Inactive" },
      ".properties.plan3_selector": { "value": "Inactive" },
      ".properties.backups_selector": { "value": "S3 Backups" },
      ".properties.backups_selector.s3.access_key_id": { "value": $aws_access_key_id },
      ".properties.backups_selector.s3.secret_access_key": { "value": $aws_secret_access_key },
      ".properties.backups_selector.s3.bucket_name": { "value": $aws_s3_bucket },
      ".properties.backups_selector.s3.path": { "value": $aws_s3_bucket_path },
      ".properties.backups_selector.s3.cron_schedule": { "value": $aws_s3_bucket_schedule },
      ".properties.backups_selector.s3.region": { "value": $aws_s3_bucket_region }
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
  --product-properties "$mysql_properties" \
  --product-network "$mysql_network" \
  --product-resources "$mysql_resources"
