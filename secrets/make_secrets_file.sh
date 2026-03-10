#! /bin/bash
THIS_SCRIPT=$(realpath "$0")
THIS_SCRIPT_DIR=$(dirname "$THIS_SCRIPT")

set -e -o pipefail

source "${THIS_SCRIPT_DIR}/sm_funcs.source"
# secrets directory contains the following files:
#  npmrc         : NPM configuration file- will be placed in $HOME/.npmrc
#  settings.xml  : Maven settings.xml file, will be placed in $HOME/.m2/settings.xml
#  artifactstores/* : artifact store definitions
#  keysets/*.keyset : keysets used for KAB creation

function usage() {
  echo "usage: $0 <secretsname>"
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi
SECRETNAME="$1"
SECRETS_DIR="${SECRET_WORKTOP_DIR}/${SECRETNAME}"
OUTPUT_FILE="$(getEncryptedSecretsFilename "$SECRETNAME")"

# confirm that the secrets directory is actually a directory.
if [ ! -d "${SECRETS_DIR}" ]; then
  echo "invalid secrets directory."
  usage
  exit 1
fi

NPMRC_FILE="npmrc"
MVNSETTINGS_FILE="settings.xml"
KEYSETS_DIR="keysets"
ARTIFACTSTORES="artifactstores"
USERSECRETS="usersecrets"

ALLFILES=""

# check for npmrc file
if [ -f "${SECRETS_DIR}/${NPMRC_FILE}" ]; then
  echo "npmrc file found"
  ALLFILES="${ALLFILES} ${NPMRC_FILE}"
else
  echo "${NPMRC_FILE} not found - node/npm builds may not work"
fi

# check for maven settings.xml file
if [ -f "${SECRETS_DIR}/${MVNSETTINGS_FILE}" ]; then
  echo "maven settings.xml file found"
  ALLFILES="${ALLFILES} ${MVNSETTINGS_FILE}"
else
  echo "maven settings.xml not found - maven builds may not work"
fi

if [ -d "${SECRETS_DIR}/${KEYSETS_DIR}" ]; then
  echo "keysets directory found"
  ALLFILES="${ALLFILES} ${KEYSETS_DIR}"
else
  echo "keysets directory not found in secrets"
fi

if [ -d "${SECRETS_DIR}/${ARTIFACTSTORES}" ]; then
  echo "artifactstores directory found"
  ALLFILES="${ALLFILES} ${ARTIFACTSTORES}"
else
  echo "artifactstores directory not found in secrets"
fi

if [ -d "${SECRETS_DIR}/${USERSECRETS}" ]; then
  echo "usersecrets directory found"
  ALLFILES="${ALLFILES} ${USERSECRETS}"
fi

## create the 7z encrypted file

# capture the password argument
if [ "${KOSBUILD_SECRET_PASSWORD}" == "" ]; then
  SECRET_DETAIL_FILENAME="$(getSecretDetailFilename "$SECRETNAME")"
  if [ -f "${SECRET_DETAIL_FILENAME}" ]; then
    KOSBUILD_SECRET_PASSWORD="$(jq -r '.password // ""' "${SECRET_DETAIL_FILENAME}")"
    echo "using password from secret-detail file"
  else
    SECRET_PASSWORD_FILE="${SECRETS_DIR}/secrets_password"
    if [ -f "${SECRET_PASSWORD_FILE}" ]; then
      KOSBUILD_SECRET_PASSWORD=$(cat "${SECRET_PASSWORD_FILE}")
      echo "using password from file ${SECRET_PASSWORD_FILE}"
    fi
  fi
fi

if [ "${KOSBUILD_SECRET_PASSWORD}" != "" ]; then
  SECRET_ARG_7Z="-p${KOSBUILD_SECRET_PASSWORD}"
else
  echo "error: KOSBUILD_SECRET_PASSWORD not defined - it must be defined in a secret detail file or in the environment"
  exit 1
fi

#  build the archive
mkdir -p "$(dirname "${OUTPUT_FILE}")"
rm -f "${OUTPUT_FILE}"
pushd "${SECRETS_DIR}"
7z a -t7z -mhe "${SECRET_ARG_7Z}" "${OUTPUT_FILE}" ${ALLFILES}
popd
