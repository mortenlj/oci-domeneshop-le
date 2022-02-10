#!/bin/bash

set -o errexit   # abort on nonzero exitstatus
set -o nounset   # abort on unbound variable

BUCKET_NAME="le-certificates"
CERT_PATH="/etc/letsencrypt"
DOMAINS="ibidem.no,*.ibidem.no,*.oci.ibidem.no"
LOG_FORMAT="${LOG_FORMAT:-plain}"

OCI_CLI_CONFIG_FILE="${OCI_CLI_CONFIG_FILE:-~/.oci/config}"

tenancy=
# shellcheck disable=SC1090
source <(grep tenancy < "${OCI_CLI_CONFIG_FILE}")
COMPARTMENT_ID="${COMPARTMENT_ID:-${tenancy}}"

export PATH="${PATH}:/opt/oci-sdk/bin:/opt/certbot/bin"

function log() {
  now=$(date -Iseconds)
  echo "[${now}] ${*}"
}

function download_certificates() {
  log "Attempting download of existing certificates"
  oci os object bulk-download --bucket-name "${BUCKET_NAME}" --download-dir "${CERT_PATH}"
}

function create_certificates() {
  log "Creating certificates"
  certbot certonly --config ./certbot.ini --domains "${DOMAINS}" --deploy-hook /app/update_certificate_in_LB.sh
}

function renew_certificates() {
  log "Renewing certificates"
  certbot renew --config ./certbot.ini
}

function configure_load_balancer() {
  log "TODO: Configuring load balancer"
}

function upload_certificates() {
  log "Uploading certificates"
  oci os object bulk-upload --overwrite --bucket-name "${BUCKET_NAME}" --src-dir "${CERT_PATH}"
}


log "Start certificate update job"

download_certificates

if [[ -r "${CERT_PATH}/renewal/ibidem.no.conf" ]]; then
  renew_certificates
else
  create_certificates
fi

configure_load_balancer

upload_certificates

log "Done"
