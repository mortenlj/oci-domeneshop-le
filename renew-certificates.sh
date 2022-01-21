#!/bin/bash

set -o errexit   # abort on nonzero exitstatus
set -o nounset   # abort on unbound variable
#set -o xtrace    # echo commands after variable expansion

#TODO: Plan of attack
# * Attempt download of certificates from OCI bucket
# * If failed, run create certificates flow, else renew
# * Create/renew certificates
# * Add certificates to Load Balancer
# * Attempt create of OCI bucket, ignore failure (assume exists)
# * Bulk upload certificates to OCI bucket

BUCKET_NAME="le-certificates"
LOG_FORMAT="${LOG_FORMAT:-plain}"

OCI_CLI_CONFIG_FILE="${OCI_CLI_CONFIG_FILE:-~/.oci/config}"

tenancy=
# shellcheck disable=SC1090
source <(grep tenancy < ${OCI_CLI_CONFIG_FILE})

COMPARTMENT_ID="${COMPARTMENT_ID:-${tenancy}}"

export PATH="${PATH}:/opt/oci-sdk/bin:/opt/certbot/bin"

function log() {
  now=$(date -Iseconds)
  if [[ ${LOG_FORMAT} == "json" ]]; then
    echo "{timestamp=\"${now}\" message=\"${*}\"}"
  else
    echo "[${now}] ${*}"
  fi
}

function download_certificates() {
  log "Attempting download of existing certificates"
  cert_path=$(mktemp --directory --suffix=-certificates)
  export cert_path
  if oci os object bulk-download --bucket-name "${BUCKET_NAME}" --download-dir "${cert_path}"; then
    return 1
  else
    return 0
  fi
}

function create_certificates() {
  log "TODO: Creating certificates"
  echo "created dummy certificate" > "${cert_path}/dummy.txt"
}

function renew_certificates() {
  log "TODO: Renewing certificates"
  echo "renewed dummy certificate at $(date -Iseconds)" > "${cert_path}/dummy.txt"
}

function configure_load_balancer() {
  log "TODO: Configuring load balancer"
}

function upload_certificates() {
  log "Uploading certificates"
  oci os object bulk-upload --overwrite --bucket-name "${BUCKET_NAME}" --src-dir "${cert_path}"
}


log "Renewing certificates"

if download_certificates; then
  create_certificates
else
  renew_certificates
fi

configure_load_balancer

upload_certificates

log "Done"
