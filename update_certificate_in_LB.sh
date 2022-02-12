#!/bin/bash

###################################################
#
# Script to upload a Let's Encrypt certificate
# (or other) into Oracle Cloud Load Balancer
# Carlos Santos - April 2020
# Modified by Morten Lied Johansen
#
###################################################

set -o errexit   # abort on nonzero exitstatus
set -o nounset   # abort on unbound variable

####################################
#                                  #
#       Variable definition        #
#                                  #
####################################

OCI_CLI_CONFIG_FILE="${OCI_CLI_CONFIG_FILE:-~/.oci/config}"

tenancy=
# shellcheck disable=SC1090
source <(grep tenancy < "${OCI_CLI_CONFIG_FILE}")
COMPARTMENT_ID="${COMPARTMENT_ID:-${tenancy}}"

now=$(date "+%Y%m%d_%H%M")
CertificateName=Certificate-$now
Protocol=HTTP
Port=443

#
# Only change the variables below
#
ListenerName=agents-https
BackendName=agents
certificate_path="${RENEWED_LINEAGE}"

####################################
# Find LB OCID                     #
####################################
echo "Finding OCID for Flex LB"

LB_OCID=$(oci lb load-balancer list --compartment-id "${COMPARTMENT_ID}" | jq -r '.data[] | select(.["display-name"] == "flex-lb") | .id')

####################################
# Create Certificate in LB         #
####################################
echo "Creating Certificate $CertificateName in Listener $ListenerName"

oci lb certificate create \
--wait-for-state SUCCEEDED --wait-for-state FAILED --wait-interval-seconds 5 \
--certificate-name $CertificateName \
--load-balancer-id $LB_OCID \
--private-key-file "$certificate_path/privkey.pem" \
--public-certificate-file "$certificate_path/fullchain.pem"

####################################
#  Update certificate on Listener  #
####################################
echo "Configuring Listener $ListenerName with certificate $CertificateName"

oci lb listener update \
--wait-for-state SUCCEEDED --wait-for-state FAILED --wait-interval-seconds 5 \
--default-backend-set-name $BackendName \
--listener-name $ListenerName \
--load-balancer-id $LB_OCID \
--port $Port \
--protocol $Protocol \
--ssl-certificate-name $CertificateName \
--cipher-suite-name oci-modern-ssl-cipher-suite-v1 \
--force
