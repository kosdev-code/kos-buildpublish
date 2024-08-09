#! /bin/bash
set -e -o pipefail

THIS_SCRIPT=$(realpath "$0")
THIS_SCRIPT_DIR=$(dirname "$THIS_SCRIPT")

function usage() {
    echo "usage: "
    echo "$0 <authtoken> <groupid> <artifactname> <version> <filename> [PUBLISHTYPE]"
    echo " will upload <filename> to the server with specified maven coordinates"
    echo
}

AUTHTOKEN="$1"
GROUPID="$2"
ARTIFACT="$3"
VERSION="$4"
FILENAME="$5"
PUBTYPE="$6"

if [ $# -lt 5 ]; then
  usage
  exit 1
fi
if [ $# -lt 6 ]; then
  PUBTYPE="USER_MANAGED"
fi

echo "$0  group artifact version =  ${GROUPID} ${ARTIFACT} ${VERSION}"

# publish to central sonatype
if [ "${GITHUB_ACTIONS}" == "true" ]; then
   echo "sending to central sonatype..."
   CENTRAL_AUTHTOKEN=$(echo "${AUTHTOKEN}" | base64)

   curl --fail --request POST \
         --header "Authorization: Bearer ${CENTRAL_AUTHTOKEN}" \
         --form "bundle=@${FILENAME}" \
         "https://central.sonatype.com/api/v1/publisher/upload?name=${GROUPID}-${ARTIFACT}-${VERSION}&publishingType=${PUBTYPE}"
else
   echo "$0 [Disabled - not in GITHUB_ACTIONS] - would send to central sonatype"
fi

