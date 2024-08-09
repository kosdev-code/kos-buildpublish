#! /bin/bash

set -e -o pipefail

function usage() {
    echo "usage: $0 <secrets file>"
    echo "  if you wish to use a password to decrypt the file, you would add that secret to the environment with name KOSBUILD_SECRET_PASSWORD."
    echo "  e.g. KOSBUILD_SECRET_PASSWORD=mypassword $0 <secrets file>"
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi
SECRETS_ARCHIVE="$1"

# output the sha256sum of the secrets archive so we have ability to debug
sha256sum "${SECRETS_ARCHIVE}"

# define the files we will process
NPMRC_FILE="npmrc"
MVNSETTINGS_FILE="settings.xml"
KEYSETS_DIR="keysets"
ARTIFACTSTORES="artifactstores"
USERSECRETS="usersecrets"

# extract the secrets to EXTRACT_DIR
EXTRACT_DIR=/tmp/secrets
## build our password parameter
[ ! -z "${KOSBUILD_SECRET_PASSWORD}" ] && SECRET_ARG_7Z="-p${KOSBUILD_SECRET_PASSWORD}"
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
    if [ "${GITHUB_ACTIONS}" == "true" ]; then
        echo "==> m2 github actions workaround <=="
        mkdir -p "/root/.m2"
        ln -s -f "$HOME/.m2/settings.xml" "/root/.m2/settings.xml"
    fi
fi

## keysets folder
if [ -d "${EXTRACT_DIR}/${KEYSETS_DIR}" ]; then
    mkdir -p $HOME/.kosbuild
    mv "${EXTRACT_DIR}/${KEYSETS_DIR}" $HOME/.kosbuild
fi

## artifactstores folder
if [ -d "${EXTRACT_DIR}/${ARTIFACTSTORES}" ]; then
    mkdir -p $HOME/.kosbuild
    mv "${EXTRACT_DIR}/${ARTIFACTSTORES}" $HOME/.kosbuild
fi

## artifactstores folder
if [ -d "${EXTRACT_DIR}/${USERSECRETS}" ]; then
    mkdir -p $HOME/.kosbuild
    mv "${EXTRACT_DIR}/${USERSECRETS}" $HOME/.kosbuild
fi

chmod 0700 "${HOME}/.kosbuild"

## cleanup
rm -rf ${EXTRACT_DIR}

# run secrets_init if it exists
SECRETS_INIT_FILE="${HOME}/.kosbuild/${USERSECRETS}/secrets_init"
if [ -f "${SECRETS_INIT_FILE}" ]; then
    chmod +x "${SECRETS_INIT_FILE}"
    echo "$0: executing secrets init..."
    ${SECRETS_INIT_FILE}
    echo "$0: secrets init done"
fi
