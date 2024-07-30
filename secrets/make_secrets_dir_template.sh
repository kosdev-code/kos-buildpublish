#! /bin/bash

if [ $# -lt 2 ]; then
  echo "usage: $0 <orgname> <password>"
  exit 1
fi

ORGNAME="$1"
PASSWORD="$2"

mkdir -p "${ORGNAME}/artifactstores"
mkdir -p "${ORGNAME}/keysets"

# create password if it doesn't exist
SECRETS_FILENAME="${ORGNAME}/secrets_password"
if [ ! -f ${SECRETS_FILENAME} ]; then 
  echo "${PASSWORD}" > "${SECRETS_FILENAME}"
else 
  echo "password file not created because it already exists"
fi

ARTSTORE_TEMPLATE='{ "type": "azurecontainer", "studio-apikey": "TODO", "container": "TODO", "sastoken": "TODO" }'
ARTSTORE_FILE="${ORGNAME}/artifactstores/template.json"

if [ ! -f "${ARTSTORE_FILE}" ]; then
  echo "${ARTSTORE_TEMPLATE}" | jq > "${ARTSTORE_FILE}"
else
  echo "artifact store template not created- it already exists."
fi


