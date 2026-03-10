#! /bin/bash
THIS_SCRIPT=$(realpath "$0")
THIS_SCRIPT_DIR=$(dirname "$THIS_SCRIPT")

set -e -o pipefail

source "${THIS_SCRIPT_DIR}/sm_funcs.source"
# The Azure Token File contains details on the remote url
AZURE_TOKEN_FILE="${DETAIL_DIR}/azure-token.json"

if [ ! -f "${AZURE_TOKEN_FILE}" ]; then
  echo "error: azure token not found: ${AZURE_TOKEN_FILE}"
  exit 1
fi

function usage() {
  echo "usage: $0 <secretsname> <github org> <repo> [SECRETS_PREFIX]"
  echo " Purpose: will configure the Github Action Secrets for a given ORG and REPO"
  echo "          including both the Secrets URL and the Password"
  echo " *** github CLI is required to run this ***"
  echo
  echo " where secretsname is the name of the secrets from the ${DETAIL_DIR} directory"
  echo " <github org> is the name of the org in Github"
  echo " <repo> is the name of the repo"
  echo " if SECRETS_PREFIX is specified, instead of setting KOSBUILD_SECRET_URL and KOSBUILD_SECRET_PASSWORD"
  echo "  then SECRETS_PREFIX will be prefix the name. e.g. if TCCC_, it would set TCCC_KOSBUILD_SECRET_URL and TCCC_KOSBUILD_SECRET_PASSWORD"
  echo
  echo " available secrets: "
  getSecretsIds
  for n in "${SECRET_NAMES_ARRAY[@]}"; do
    echo "  $n"
  done
  exit 1
}

if [ $# -lt 3 ]; then
  usage
fi

SECRETNAME="$1"
GITHUBORG="$2"
GITHUBREPO="$3"
SECRETS_PREFIX="$4"

SECRETS_DETAIL_FILE="$(getSecretDetailFilename "$SECRETNAME")"
ENCRYPTED_SECRETS_FILE="$(getEncryptedSecretsFilename "$SECRETNAME")"

if [ "$(which gh)" == "gh not found" ]; then
  echo "github CLI needs to be installed to set secrets"
  exit 1

fi

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

if [ "${SECRETS_PREFIX}" != "" ]; then
  confirm "Secrets Prefix detected.  Publish ${SECRETS_PREFIX}KOSBUILD_SECRET_URL and ${SECRETS_PREFIX}KOSBUILD_SECRET_PASSWORD ?"
fi

JSON_FILE="${DETAIL_DIR}/log-github-${SECRETNAME}.json"

# extract the details on the storage account
CONTAINER="$(jq -r '.container // ""' "${AZURE_TOKEN_FILE}")"
DESTURL="${CONTAINER}/$(basename "${ENCRYPTED_SECRETS_FILE}")"

# extract the details from the secrets detail file
DETAIL_SECRETS_URL="$(jq -r '.url // ""' "${SECRETS_DETAIL_FILE}")"
DETAIL_SECRETS_PASSWORD="$(jq -r '.password // ""' "${SECRETS_DETAIL_FILE}")"

if [ ! -z "${DETAIL_SECRETS_URL}" ] && [ "${DETAIL_SECRETS_URL}" != "${DESTURL}" ]; then
  echo "URL from Secrets-Detail:  ${DETAIL_SECRETS_URL}"
  echo "Secrets URL:              ${DESTURL}"

  confirm "WARNING: Secrets URL does not match secrets-detail URL. We will use Secrets URL. Continue?"
fi

echo "setting Secrets URL ${DESTURL} (${SECRETS_PREFIX}KOSBUILD_SECRET_URL) to ${GITHUBORG}/${GITHUBREPO}"

gh secret set "${SECRETS_PREFIX}KOSBUILD_SECRET_URL" --repo "${GITHUBORG}/${GITHUBREPO}" --body "${DESTURL}"
echo "setting Secrets Password (${SECRETS_PREFIX}KOSBUILD_SECRET_PASSWORD) to ${GITHUBORG}/${GITHUBREPO}"

echo "setting Secrets password (${SECRETS_PREFIX}KOSBUILD_SECRET_PASSWORD) to ${GITHUBORG}/${GITHUBREPO}"
gh secret set "${SECRETS_PREFIX}KOSBUILD_SECRET_PASSWORD" --repo "${GITHUBORG}/${GITHUBREPO}" --body "${DETAIL_SECRETS_PASSWORD}"

# we will log each repository that we configure and the date so that we have a record of it.
update_json_entries "${JSON_FILE}" "${GITHUBORG}" "${GITHUBREPO}" "${SECRETS_PREFIX}"
