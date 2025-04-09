#! /bin/bash
THIS_SCRIPT=$(realpath "$0")
THIS_SCRIPT_DIR=$(dirname "$THIS_SCRIPT")

set -e -o pipefail

source "${THIS_SCRIPT_DIR}/sm_funcs.source"

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
SECRETS_FILE="$(getSecretDetailFilename "$SECRETNAME")"

# look for the secrets management file
if [ ! -f "${SECRETS_FILE}" ]; then
   echo "error: file not found: ${SECRETS_FILE}"
   exit 1
fi

# extract the URL/password
SECRETS_URL="$(jq -r '.url // ""' "${SECRETS_FILE}")"
SECRETS_PASSWORD="$(jq -r '.password // ""' "${SECRETS_FILE}")"

# if there's no secrets-url, then try to use the azure url
if [ -z "${SECRETS_URL}" ]; then
   AZURE_TOKEN_FILE="${DETAIL_DIR}/azure-token.json"
   if [ -f "${AZURE_TOKEN_FILE}" ]; then
      CONTAINER="$(jq -r '.container // ""' "${AZURE_TOKEN_FILE}")"
      ENCRYPTED_SECRETS_FILE="$(getEncryptedSecretsFilename "$SECRETNAME")"
      SECRETS_URL="${CONTAINER}/$(basename "${ENCRYPTED_SECRETS_FILE}")"
   fi
fi

if [ -z "${SECRETS_URL}" ]; then
   echo "error: no secrets URL defined."
   exit 1
fi
# remove existing download if it exists, then download the current one
echo "url: ${SECRETS_URL}"
SECRETS_BASEFILE="$(basename "$SECRETS_URL")"
mkdir -p "${DL_DIR}"
rm -f "${DL_DIR}/${SECRETS_BASEFILE}"

echo "downloading with curl..."
curl -f -o "${DL_DIR}/${SECRETS_BASEFILE}" "${SECRETS_URL}"

echo "download complete"

# now, expand it into the work directory
mkdir -p "$SECRET_WORKTOP_DIR"

if [ -d "${SECRET_WORKTOP_DIR}/${SECRETNAME}" ]; then 
   if confirm "Secret directory ${SECRETNAME} already exists.  Replace?"; then
      # copy previous secret directory to a backup directory, replacing it if it exists in the backup directory
      mkdir -p "${SECRET_WORKTOP_BACKUP_DIR}"
      rm -rf "${SECRET_WORKTOP_BACKUP_DIR}/${SECRETNAME}"
      cp -a "${SECRET_WORKTOP_DIR}/${SECRETNAME}" "${SECRET_WORKTOP_BACKUP_DIR}"
      rm -rf "${SECRET_WORKTOP_DIR}/${SECRETNAME}"
   else
      echo "stopping due to user request"
      exit 1
   fi
fi

# extract secrets file to tmp dir
EXTRACT_DIR="${SECRET_WORKTOP_DIR}/tmp"
rm -rf "${EXTRACT_DIR}"
mkdir -p "${EXTRACT_DIR}"
echo "extracting secrets to temporary path"
# extract secrets
7z x "-p${SECRETS_PASSWORD}" -o"${EXTRACT_DIR}" "${DL_DIR}/${SECRETS_BASEFILE}"
echo "extraction successful.  moving secrets to ${SECRET_WORKTOP_DIR}/${SECRETNAME}"
mv "${EXTRACT_DIR}" "${SECRET_WORKTOP_DIR}/${SECRETNAME}"

echo "COMPLETE: secrets are now available in ${SECRET_WORKTOP_DIR}/${SECRETNAME}"


