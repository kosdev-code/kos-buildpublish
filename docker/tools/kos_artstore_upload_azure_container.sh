#! /bin/bash
set -e -o pipefail

function usage() {
    echo "$0 <local filename> <repo> <remotefilename>"
    echo " will upload the file to an azure container"
}

LOCALFILE="$1"
REPO="$2"
REMOTEFILENAME="$3"

if [ $# -lt 3 ]; then
  usage
  exit 1
fi

ARTSTORE_FILENAME="$HOME/.kosbuild/artifactstores/${REPO}.json"
# get the container and token
ARTSTORE_CONTAINER=$(jq -r ".container" "${ARTSTORE_FILENAME}")
ARTSTORE_SASTOKEN=$(jq -r ".sastoken" "${ARTSTORE_FILENAME}")

REMOTEURL="${ARTSTORE_CONTAINER}/${REMOTEFILENAME}?${ARTSTORE_SASTOKEN}"

echo "uploading ${LOCALFILE} to azure container ${ARTSTORE_CONTAINER} using azcopy..."
azcopy cp --log-level=NONE --output-level=essential --skip-version-check "${LOCALFILE}" "${REMOTEURL}"

echo "upload complete"
