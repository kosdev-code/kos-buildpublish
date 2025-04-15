#! /bin/bash
THIS_SCRIPT=$(realpath "$0")
THIS_SCRIPT_DIR=$(dirname "$THIS_SCRIPT")

set -e -o pipefail

source "${THIS_SCRIPT_DIR}/sm_funcs.source"

function usage() {
    echo "usage: $0 <secretsname>"
    echo " will test the integreity of the encrypted secrets file"
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi
SECRETNAME="$1"
OUTPUT_FILE="$(getEncryptedSecretsFilename "$SECRETNAME")"


# capture the password argument
SECRET_DETAIL_FILENAME="$(getSecretDetailFilename "$SECRETNAME")"
KOSBUILD_SECRET_PASSWORD="$(jq -r '.password // ""' "${SECRET_DETAIL_FILENAME}")"
SECRET_ARG_7Z="-p${KOSBUILD_SECRET_PASSWORD}"

#  build the archive
7z t "${SECRET_ARG_7Z}" "${OUTPUT_FILE}"

echo "success"

