#!/bin/bash

echo "Renewing certificates"
echo ""
cat <<EOF
TODO: Plan of attack
 * Attempt download of certificates from OCI bucket
 * If failed, run create certificates flow, else renew
 * Create/renew certificates
 * Add certificates to Load Balancer
 * Attempt create of OCI bucket, ignore failure (assume exists)
 * Bulk upload certificates to OCI bucket
EOF
echo "Done"
