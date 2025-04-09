#! /bin/bash
THIS_SCRIPT=$(realpath "$0")
THIS_SCRIPT_DIR=$(dirname "$THIS_SCRIPT")

set -e -o pipefail

source "${THIS_SCRIPT_DIR}/sm_funcs.source"
SECRETID=developer

TGTDIR="${SECRET_WORKTOP_DIR}/$SECRETID"
mkdir -p "${TGTDIR}"

if [ -f "${HOME}/.npmrc" ]; then
echo "installing .npmrc file"
cp "${HOME}/.npmrc" "${TGTDIR}/npmrc"
fi

if [ -f "${HOME}/.m2/settings.xml" ]; then
echo "installing maven settings.xml file"
cp "${HOME}/.m2/settings.xml" "${TGTDIR}/settings.xml"
fi

if [ -f "${HOME}/kosStudio/tools.properties" ]; then
  keyset_value=$(perl -nle 'print $1 if /keyset = (.*)/' "${HOME}/kosStudio/tools.properties")
  if [ -f "${keyset_value}" ]; then 
    echo "installing developer keyset ${keyset_value}"

    mkdir -p "${TGTDIR}/keysets"
    cp "${keyset_value}" "${TGTDIR}/keysets/${SECRETID}.keyset"
  fi
fi

if [ -d "${HOME}/.ssh" ]; then
  echo "copying ssh private keys to secrets"
  mkdir -p "${TGTDIR}/usersecrets/ssh-private"
  cp -r ${HOME}/.ssh/* "${TGTDIR}/usersecrets/ssh-private"
  cp "${THIS_SCRIPT_DIR}/developer_secrets_init" "${TGTDIR}/usersecrets/secrets_init"
fi

# set the encrypted 7z password - fixed password for the developer org
SECRET_DETAIL_FILENAME="$(getSecretDetailFilename "$SECRETID")"
PASSWORD=developer
echo '{ "url": "", "password": "'${PASSWORD}'"}' | jq > "${SECRET_DETAIL_FILENAME}"

echo "create secrets file"
"${THIS_SCRIPT_DIR}/make_secrets_file.sh" "${SECRETID}"

echo "You can customize the $SECRETID directory for your needs (${TGTDIR})."
echo "When done, simply create the secrets file again."


