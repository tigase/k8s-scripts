#!/bin/bash
#
# Script updates records of a DNS ZONE on AWS Route53
#
# $1 - mandatory domain zone ID on AWS Route53
# $2 - mandatory email server, like mail.example.com, that is address to which
#      email app connects over IMAP to retrieve and send emails.
# $3 - mandatory email server IP address.
# $4 - optional email domain, like example.com
#      that is address with email accounts like user@example.com
# $5 - optional email domain IP address. If the email domain is used to connect
#      to the server, like for webmail or anything it needs IP address as well


ZONE_ID="${1}"
EMAIL_SERVER="${2}"
SERVER_IP="${3}"

EMAIL_DOMAIN="${4}"
DOMAIN_IP="${5}"

cat <<EOF > ~/tmp-zone.json
{
    "HostedZoneId": "${ZONE_ID}",
    "ChangeBatch": {
        "Comment": "",
        "Changes": [
            {
                "Action": "UPSERT",
                "ResourceRecordSet": {
                    "Name": "${EMAIL_SERVER}",
                    "Type": "A",
                    "TTL": 300,
                    "ResourceRecords": [
                        {
                            "Value": "${SERVER_IP}"
                        }
                    ]
                }
            }
EOF

[ -z "${EMAIL_DOMAIN}" ] || cat <<EOF >> ~/tmp-zone.json
,
            {
                "Action": "UPSERT",
                "ResourceRecordSet": {
                    "Name": "${EMAIL_DOMAIN}",
                    "Type": "A",
                    "TTL": 300,
                    "ResourceRecords": [
                        {
                            "Value": "${DOMAIN_IP}"
                        }
                    ]
                }
            }
EOF

cat <<EOF >> ~/tmp-zone.json
        ]
    }
}
EOF

aws route53 change-resource-record-sets --cli-input-json file://~/tmp-zone.json

