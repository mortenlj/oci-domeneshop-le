#!/bin/bash

set -o errexit # abort on nonzero exitstatus
set -o nounset # abort on unbound variable

BUCKET_NAME="le-certificates"
TARBALL_NAME="le-certificates.tar.bz2"
CERT_PATH="/etc/letsencrypt"
MAIN_DOMAIN=ibidem.no
DOMAINS="${MAIN_DOMAIN},*.${MAIN_DOMAIN},*.oci.${MAIN_DOMAIN}"
LOG_FORMAT="${LOG_FORMAT:-plain}"

OCI_CLI_CONFIG_FILE="${OCI_CLI_CONFIG_FILE:-~/.oci/config}"

tenancy=
# shellcheck disable=SC1090
source <(grep tenancy <"${OCI_CLI_CONFIG_FILE}")
COMPARTMENT_ID="${COMPARTMENT_ID:-${tenancy}}"

export PATH="${PATH}:/opt/oci-sdk/bin:/opt/certbot/bin"

function log() {
  now=$(date -Iseconds)
  echo "[${now}] ${*}"
}

function download_certificates() {
  log "Attempting download of existing certificates"
  target_file=$(mktemp -t certificates-XXXXXXX.tar.bz2)
  if oci os object get --bucket-name "${BUCKET_NAME}" --name "${TARBALL_NAME}" --file "${target_file}"; then
    log "Downloaded existing tarball, unpacking"
    tar xjvf "${target_file}" -C /
  fi
}

function upload_certificates() {
  log "Creating tarball of certificates"
  target_file=$(mktemp -t certificates-XXXXXXX.tar.bz2)
  tar cjvf "${target_file}" "${CERT_PATH}"
  log "Uploading certificates"
  oci os object put --bucket-name "${BUCKET_NAME}" --name "${TARBALL_NAME}" --file "${target_file}" --force --verify-checksum
}

function create_certificates() {
  log "Creating certificates"
  certbot certonly --config ./certbot.ini --domains "${DOMAINS}"
  RENEWED_LINEAGE="/etc/letsencrypt/live/${MAIN_DOMAIN}" /app/update_certificate_in_LB.sh
}

function renew_certificates() {
  log "Renewing certificates"
  certbot renew --config ./certbot.ini --deploy-hook /app/update_certificate_in_LB.sh
}

log "Start certificate update job"

download_certificates

if [[ -r "${CERT_PATH}/renewal/ibidem.no.conf" ]]; then
  renew_certificates
else
  create_certificates
fi

upload_certificates

log "Done"
