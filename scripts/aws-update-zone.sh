#!/bin/bash
#
# Script updates records of a DNS ZONE on AWS Route53
#
# $1 - mandatory domain zone ID on AWS Route53
# $2 - mandatory hostname, like mail.example.com
# $3 - mandatory server IP address.
# $4 - optional AWS profile


ZONE_ID="${1}"
HOSTNAME="${2}"
IP="${3}"
PROFILE="${4}"

cat <<EOF > ~/tmp-zone.json
{
    "HostedZoneId": "${ZONE_ID}",
    "ChangeBatch": {
        "Comment": "",
        "Changes": [
            {
                "Action": "UPSERT",
                "ResourceRecordSet": {
                    "Name": "${HOSTNAME}",
                    "Type": "A",
                    "TTL": 300,
                    "ResourceRecords": [
                        {
                            "Value": "${IP}"
                        }
                    ]
                }
            }
        ]
    }
}
EOF

[[ -n "${PROFILE}" ]] && export AWS_PROFILE=${PROFILE}

aws route53 change-resource-record-sets --cli-input-json file://~/tmp-zone.json 

