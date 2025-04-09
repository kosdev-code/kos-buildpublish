#! /bin/bash
THIS_SCRIPT=$(realpath "$0")
THIS_SCRIPT_DIR=$(dirname "$THIS_SCRIPT")

set -e -o pipefail

source "${THIS_SCRIPT_DIR}/sm_funcs.source"

# The Azure Token File contains details on how to upload
AZURE_TOKEN_FILE="${DETAIL_DIR}/azure-token.json"
if [ ! -f "${AZURE_TOKEN_FILE}" ]; then
  echo "error: azure token not found: ${AZURE_TOKEN_FILE}"
  exit 1
fi


function usage() {
    echo "usage: $0 <secretsname>"
    echo " where secretsname is the name of the secrets from the ${DETAIL_DIR} directory"
    echo " available secrets: "
    getSecretsIds
    for n in "${SECRET_NAMES_ARRAY[@]}"; do
        echo "  $n"
    done

    exit 1
}

if [ $# -lt 1 ]; then
usage
fi

SECRETNAME="$1"
SECRETS_DETAIL_FILE="$(getSecretDetailFilename "$SECRETNAME")"
ENCRYPTED_SECRETS_FILE="$(getEncryptedSecretsFilename "$SECRETNAME")"

if [ "$SECRETNAME" == "developer" ]; then
  echo "developer secrets may not be pushed"
  exit 1
fi
# look for the secrets management file
if [ ! -f "${SECRETS_DETAIL_FILE}" ]; then
  echo "error: file not found: ${SECRETS_DETAIL_FILE}"
  exit 1
fi

if [ ! -f "${ENCRYPTED_SECRETS_FILE}" ]; then
  echo "error: file not found: ${ENCRYPTED_SECRETS_FILE}"
  exit 1
fi

# extract the details on the storage account
CONTAINER="$(jq -r '.container // ""' "${AZURE_TOKEN_FILE}")"
SASTOKEN="$(jq -r '.sas // ""' "${AZURE_TOKEN_FILE}")"

GIVENURL=$(jq -r '.url // ""' "${SECRETS_DETAIL_FILE}")
DESTURL="${CONTAINER}/$(basename "${ENCRYPTED_SECRETS_FILE}")"

if [ "${GIVENURL}" != "" ] && [ "${GIVENURL}" != "${DESTURL}" ]; then
  echo "URL from Secrets-Detail file: ${GIVENURL}"
  echo "Destination URL:              ${DESTURL}"
  
  confirm "WARNING: Destination URL does not match secrets-detail URL.  Upload anyway?"
fi

echo "secrets file ${ENCRYPTED_SECRETS_FILE} to be uploaded to ${DESTURL}"

echo "uploading..."
azcopy cp "${ENCRYPTED_SECRETS_FILE}" "${DESTURL}?${SASTOKEN}"
echo "azcopy completed."
