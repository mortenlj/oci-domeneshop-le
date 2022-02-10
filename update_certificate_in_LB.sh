#!/bin/bash

###################################################
#
# Script to upload a Let's Encrypt certificate
# (or other) into Oracle Cloud Load Balancer
# Carlos Santos - April 2020
# Modified by Morten Lied Johansen
#
###################################################

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
certificate_path=/etc/letsencrypt/live/ibidem.no

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
--certificate-name $CertificateName \
--load-balancer-id $LB_OCID \
--private-key-file "$certificate_path/privkey.pem" \
--public-certificate-file "$certificate_path/fullchain.pem"

#
# Give it 10 seconds for the certificate to be available
#
echo "-- Waiting 10 seconds for certificate to be available on OCI"
sleep 10

####################################
#  Update certificate on Listener  #
####################################
echo "Configuring Listener $ListenerName with certificate $CertificateName"

oci lb listener update \
--default-backend-set-name $BackendName \
--listener-name $ListenerName \
--load-balancer-id $LB_OCID \
--port $Port \
--protocol $Protocol \
--ssl-certificate-name $CertificateName \
--force
