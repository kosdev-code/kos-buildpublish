#! /bin/bash
THIS_SCRIPT=$(realpath "$0")
THIS_SCRIPT_DIR=$(dirname "$THIS_SCRIPT")

set -e -o pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 <orgname> <password>"
  exit 1
fi

source "${THIS_SCRIPT_DIR}/sm_funcs.source"

ORGNAME="$1"
PASSWORD="$2"

SECRET_DETAIL_FILENAME="$(getSecretDetailFilename "$ORGNAME")"

mkdir -p "${SECRET_WORKTOP_DIR}/${ORGNAME}/artifactstores"
mkdir -p "${SECRET_WORKTOP_DIR}/${ORGNAME}/keysets"
mkdir -p "${SECRET_WORKTOP_DIR}/${ORGNAME}/usersecrets"

# create password if it doesn't exist
if [ ! -f "${SECRET_DETAIL_FILENAME}" ]; then
  echo '{ "url": "", "password": "'${PASSWORD}'"}' | jq > "${SECRET_DETAIL_FILENAME}"
else
  FILE_PASSWORD="$(jq -r '.password // ""' "${SECRET_DETAIL_FILENAME}")"
  if [ "$FILE_PASSWORD" != "${PASSWORD}" ]; then
     echo "error: given password does not match secret-detail file"
     exit 1
  fi
  echo "secret detail file already exists.  Not creating."
fi

ARTSTORE_TEMPLATE='{ "type": "azurecontainer", "studio-apikey": "TODO", "container": "TODO", "sastoken": "TODO" }'
ARTSTORE_FILE="${SECRET_WORKTOP_DIR}/${ORGNAME}/artifactstores/template.json"

if [ ! -f "${ARTSTORE_FILE}" ]; then
  echo "${ARTSTORE_TEMPLATE}" | jq > "${ARTSTORE_FILE}"
else
  echo "artifact store template not created- it already exists."
fi

echo "template secrets directory has been created in $(realpath ${SECRET_WORKTOP_DIR}/${ORGNAME})."
echo "Fill it in with your details.  When done, you can run make_secrets_file.sh to create an encrypted 7z suitable for deployment"

