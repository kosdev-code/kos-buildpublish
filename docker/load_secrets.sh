#! /bin/bash

set -e -o pipefail

function usage() {
    echo "usage: $0 <secrets file>"
    echo "  if you wish to use a password to decrypt the file, you would add that secret to the environment with name SECRET_PASSWORD."
    echo "  e.g. SECRET_PASSWORD=mypassword $0 <secrets file>"
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi
SECRETS_ARCHIVE="$1"

# define the files we will process
NPMRC_FILE="npmrc"
MVNSETTINGS_FILE="settings.xml"
KEYSETS_DIR="keysets"

# extract the secrets to EXTRACT_DIR
EXTRACT_DIR=/tmp/secrets
## build our password parameter
[ ! -z "${SECRET_PASSWORD}" ] && SECRET_ARG_7Z="-p${SECRET_PASSWORD}"
## remove the output directory if it exists already
rm -rf "${EXTRACT_DIR}"
## extract the archive
echo "extracting secrets..."
7z x "${SECRET_ARG_7Z}" -o"${EXTRACT_DIR}" "${SECRETS_ARCHIVE}"


echo "installing secrets..."
# Install the secrets to the proper location
## npmrc
if [ -f "${EXTRACT_DIR}/${NPMRC_FILE}" ]; then
    mv "${EXTRACT_DIR}/${NPMRC_FILE}" $HOME/.npmrc
fi

## .m2/settings.xml
if [ -f "${EXTRACT_DIR}/${MVNSETTINGS_FILE}" ]; then
    mkdir -p $HOME/.m2
    mv "${EXTRACT_DIR}/${MVNSETTINGS_FILE}" $HOME/.m2
fi

## keysets folder
if [ -d "${EXTRACT_DIR}/${KEYSETS_DIR}" ]; then
    mkdir -p $HOME/.kosbuild
    mv "${EXTRACT_DIR}/${KEYSETS_DIR}" $HOME/.kosbuild
fi

## cleanup
rm -rf ${EXTRACT_DIR}