#! /bin/bash

set -e -o pipefail

DEFAULT_STUDIO_SERVER="https://studio.kosdev.com"

function usage() {
  echo "usage: $0 <id> <qualifier> <version> <artifactstore>"
  echo " this script will resolve a market artifact from Studio Server, returning a https URL where it may be accessed."
  exit 1
}

if [ $# -lt 4 ]; then
  usage
  exit 1
fi

# 
ARTID="kos.prod-$1"
ARTQUAL="$2"
ARTVERSION="$3"
ARTSTORE="$4"

ARTSTORE_FILENAME="${HOME}/.kosbuild/artifactstores/${ARTSTORE}.json"

if [ ! -f "${ARTSTORE_FILENAME}" ]; then
  echo "error: $0 no artifact store found (${ARTSTORE_FILENAME})"
  exit 1
fi

# get variables from artifactstore
IS_MARKET="$(jq -r '.marketplace' "${ARTSTORE_FILENAME}")"
[ "${IS_MARKET}" != "true" ] && IS_MARKET="false"
APIKEY="$(jq -r '.["studio-apikey"]' "${ARTSTORE_FILENAME}")"
[ "${APIKEY}" == "null" ] && echo "invalid apikey on repo ${ARTSTORE}. Exiting..." && exit 1


RESOLVE_OUTPUT=$(curl -s  "${DEFAULT_STUDIO_SERVER}/api/orgs/market/resolve/${ARTID}/${ARTQUAL}/${ARTVERSION}/?apiKey=${APIKEY}")

STATUS="$(echo "${RESOLVE_OUTPUT}" | jq -r ".status")"
VERSION="$(echo "${RESOLVE_OUTPUT}" | jq -r ".version.major")"
LOCATION="$(echo "${RESOLVE_OUTPUT}" | jq -r ".data.location")"
BASEURL="$(echo "${RESOLVE_OUTPUT}" | jq -r ".data.baseUrl")"

#echo "Status: ${STATUS}"
#echo "VERSION: ${VERSION}"
if [ "${STATUS}" != "200" ] || [ "${VERSION}" != "1" ]; then
    echo "error: $0 received an invalid response ${STATUS}/${VERSION}" 1>&2
    exit 1
fi
if [ "${LOCATION}" == "null" ]; then
    echo "error: $0 could not resolve ${ARTID}." 1>&2
    exit 1
fi

#echo "LOCATION: ${LOCATION}"
#echo "URL: ${BASEURL}"

if [ "${BASEURL}" == "null" ]; then
  echo "${LOCATION}"
else 
  echo "${BASEURL}/${LOCATION}"
fi
