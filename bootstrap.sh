#!/bin/bash

set -o errexit   # abort on nonzero exitstatus
set -o nounset   # abort on unbound variable
#set -o xtrace    # echo commands after variable expansion

# Bootstrap script for oci-domeneshop-le
#
# This script is meant to be run once from dev-machine
# It will:
# - create bucket for certificate storage
# - create service account for updating certificates
# - Use kubeseal to create sealed secret with OCI SDK credentials for service account
# The sealed secret and a cronjob manifest should be checked into git
# The manifest can be deployed either directly with kubectl apply, or using manifests on k3s-server

BUCKET_NAME=le-certificates
USER_NAME=oci-domeneshop-le
GROUP_NAME=oci-domeneshop-le
BUCKET_POLICY_NAME=le-certificates-access
LB_POLICY_NAME=le-lb-access

LOG_FORMAT="${LOG_FORMAT:-plain}"
MOUNT_PATH="/var/run/secrets/ibidem.no/oci-sa"

tenancy=
# shellcheck disable=SC1090
source <(grep tenancy < ~/.oci/config)

COMPARTMENT_ID="${COMPARTMENT_ID:-${tenancy}}"


function log() {
  now=$(date -Iseconds)
  if [[ ${LOG_FORMAT} == "json" ]]; then
    echo "{timestamp=\"${now}\" message=\"${*}\"}"
  else
    echo "[${now}] ${*}"
  fi
}

function create_bucket() {
  log "Ensuring bucket exists"
  oci os bucket create --name "${BUCKET_NAME}" --compartment-id "${COMPARTMENT_ID}" || true
}

function create_service_account() {
  log "Creating service account"
  user_id=$(oci iam user create --name "${USER_NAME}" --description "SA for oci-domeneshop-le cronjob" --query data.id --raw-output)

  config_dir=./secret_contents/oci-sa
  rm -rf ${config_dir}
  mkdir -p ${config_dir}
  config_file="${config_dir}/config"
  private_key_file="${config_dir}/private_key.pem"
  public_key_file="${config_dir}/public_key.pem"

  log "Creating API key pair in ${config_dir}"
  openssl genrsa -out "${private_key_file}" 2048
  chmod go-rwx "${private_key_file}"
  openssl rsa -pubout -in "${private_key_file}" -out "${public_key_file}"
  fingerprint=$(openssl rsa -pubout -outform DER -in "${private_key_file}" | openssl md5 -c | awk '{print $2}')

  oci iam user api-key upload --user-id "${user_id}" --key-file="${public_key_file}"

  log "Creating API config file in ${config_file}"
  cat > ${config_file} <<EOF
[DEFAULT]
user=${user_id}
fingerprint=${fingerprint}
key_file=${MOUNT_PATH}/private_key.pem
tenancy=${tenancy}
region=eu-zurich-1
EOF

  chmod u=rw,g=,o= ${config_dir}/*

  export user_id
  export config_dir
}

function grant_access() {
  log "Creating user group"
  group_id=$(oci iam group create --name "${GROUP_NAME}" --description "Read/write access to LE certificates" --query data.id --raw-output)

  log "Adding ${USER_NAME} to group ${GROUP_NAME}"
  oci iam group add-user --user-id=${user_id} --group-id=${group_id}

  log "Creating ${BUCKET_POLICY_NAME} policy for ${GROUP_NAME}"
  oci iam policy create --compartment-id "${COMPARTMENT_ID}" --name "${BUCKET_POLICY_NAME}" --description "Read/write access to LE certificates" \
    --statements "[\"Allow group ${GROUP_NAME} to read buckets in tenancy\", \"Allow group ${GROUP_NAME} to manage objects in tenancy where any {request.permission='OBJECT_CREATE', request.permission='OBJECT_INSPECT', request.permission='OBJECT_READ', request.permission='OBJECT_OVERWRITE'}\"]"

  log "Creating ${LB_POLICY_NAME} policy for ${GROUP_NAME}"
  oci iam policy create --compartment-id "${COMPARTMENT_ID}" --name "${LB_POLICY_NAME}" --description "Read/write access to flex-lb" \
    --statements "[\"Allow group ${GROUP_NAME} to use load-balancers in tenancy\"]"
}

function seal_secret() {
    log "Seal OCI secret"
    log "Fetch kubeseal cert"
    cert_pem=$(mktemp --suffix=.pem)
    kubectl --namespace kube-system port-forward svc/sealed-secrets-controller 8080:8080 &
    pf_pid=$!
    sleep 2
    curl http://localhost:8080/v1/cert.pem > "${cert_pem}"
    log "kubeseal cert saved to ${cert_pem}"
    echo "---" > deploy/sealed-secret.yaml
    kubectl create secret generic --namespace=default --dry-run=client "--from-file=${config_dir}" oci-sa-domeneshop -oyaml | kubeseal --cert "${cert_pem}" --format yaml >> deploy/sealed-secret.yaml
    kill ${pf_pid}
}

log "Bootstrapping oci-domeneshop-le"

create_bucket
create_service_account
grant_access
seal_secret

log "Done"
