#! /bin/bash

set -e -o pipefail

# secrets directory contains the following files:
#  npmrc         : NPM configuration file- will be placed in $HOME/.npmrc
#  settings.xml  : Maven settings.xml file, will be placed in $HOME/.m2/settings.xml
#  artifactstores/* : artifact store definitions
#  keysets/*.keyset : keysets used for KAB creation

function usage() {
    echo "usage: $0 <secrets directory> [secrets-output file]"
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi
SECRETS_DIR="$1"
OUTPUT_FILE="$(pwd)/secrets_mount/$(basename ${SECRETS_DIR})-secrets.7z"
if [ $# -gt 1 ]; then
OUTPUT_FILE="$(realpath $2)"
fi

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
SECRET_PASSWORD_FILE="${SECRETS_DIR}/secrets_password"
if [ -f "${SECRET_PASSWORD_FILE}" ]; then
    KOSBUILD_SECRET_PASSWORD=$(cat ${SECRET_PASSWORD_FILE})
    echo "using password from file ${SECRET_PASSWORD_FILE}"
fi
if [ "${KOSBUILD_SECRET_PASSWORD}" != "" ]; then
SECRET_ARG_7Z="-p${KOSBUILD_SECRET_PASSWORD}"
else
echo "error: KOSBUILD_SECRET_PASSWORD not defined - define it or include a file ${SECRET_PASSWORD_FILE}"
exit 1
fi

# save the secrets archive to a directory called secrets_mount, in a file called secrets.7z
#  build the archive
mkdir -p "$(dirname "${OUTPUT_FILE}")"
rm -f "${OUTPUT_FILE}"
pushd "${SECRETS_DIR}"
7z a -t7z -mhe ${SECRET_ARG_7Z} "${OUTPUT_FILE}" ${ALLFILES}
popd
