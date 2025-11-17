#! /bin/bash

set -e -o pipefail

# default to dry-run, if --delete is passed as an argument, we will actually delete files
DRY_RUN=1
DEFAULT_STUDIO_SERVER="https://studio.kosdev.com"

function usage() {
  echo "usage: $0 <artifact store name> [--delete]"
  echo " this script will garbage collect the referenced artifact store. (artifact store must be installed in your environment)"
  echo " by default, the script will not delete files, but if --delete is specified, the actual delete occurs"
  exit 1
}

# given a url, remove the protocol and servername
function removeServerPrefix() {
  local URL
  URL="$1"
  url_no_protocol="${URL#*://}"
  # Then remove up to and including the first slash after the server name
  url_no_server="${url_no_protocol#*/}"
  echo "${url_no_server}"
}

# returns a list of market artifacts from the server
function getMarketArtifactInstances() {
    SERVER="$1"
    REPO="$2"
    APIKEY="$3"
    CONTAINERURL="$4"

    INSTANCES=$(curl -s -f "${SERVER}/api/orgs/market/instances/${REPO}?apiKey=${APIKEY}")

    STATUS=$(echo "${INSTANCES}" | jq -r ".status")
    VERSION_MAJOR=$(echo "${INSTANCES}" | jq -r ".version.major")

    if [ "${STATUS}" != "200" ] || [ "${VERSION_MAJOR}" != "1" ]; then
       echo "invalid status/version ${STATUS}/${VERSION_MAJOR}" 1>&2
       exit 1
    fi
    INSTANCES=$(echo ${INSTANCES} | jq -r '.data[]')

    # special handling in case a full URL was given.  We will remove the protocol and server name
    # if we actually removed it, we will also remove the directory name
    local i
    local NEWINSTANCES=""
    local PREFIX
    PREFIX="$( removeServerPrefix $CONTAINERURL)/"
    for i in $INSTANCES; do
      local mod
      mod="$(removeServerPrefix $i)"
      if [ "$mod" != "$i" ]; then
         if [[ $mod == $PREFIX* ]]; then
           mod="${mod#$PREFIX}"
         fi
      fi
      NEWINSTANCES+="$mod"$'\n'
    done
    echo "${NEWINSTANCES}"
}

# returns a list of nonmarket artifacts from the server
function getNonmarketArtifactInstances() {
    SERVER="$1"
    REPO="$2"
    APIKEY="$3"
    CONTAINERURL="$4"


    INSTANCES=$(curl -s -f "${SERVER}/api/orgs/instances/${REPO}?apiKey=${APIKEY}")
    STATUS=$(echo "${INSTANCES}" | jq -r ".status")
    VERSION_MAJOR=$(echo "${INSTANCES}" | jq -r ".version.major")

    if [ "${STATUS}" != "200" ] || [ "${VERSION_MAJOR}" != "1" ]; then
       echo "invalid status/version ${STATUS}/${VERSION_MAJOR}" 1>&2
       exit 1
    fi
    INSTANCES=$(echo ${INSTANCES} | jq -r '.data[]')

    # special handling in case a full URL was given.  We will remove the protocol and server name
    # if we actually removed it, we will also remove the directory name
    local i
    local NEWINSTANCES=""
    local PREFIX
    PREFIX="$( removeServerPrefix $CONTAINERURL)/"
    for i in $INSTANCES; do
      local mod
      mod="$(removeServerPrefix $i)"
      if [ "$mod" != "$i" ]; then
         if [[ $mod == $PREFIX* ]]; then
           mod="${mod#$PREFIX}"
         fi
      fi
      NEWINSTANCES+="$mod"$'\n'
    done
    echo "${NEWINSTANCES}"
}
# returns a list of files in an azure container that are at least a day old
function getAzureStorageFileList() {
  local ABSURL="$1"
  local SASTKN="$2"
  local CONTAINERFILES

  LAST_CONTAINERLIST=$(curl -f -s -X GET "${ABSURL}?restype=container&comp=list&${SASTKN}" -H "x-ms-version: 2020-10-02")
  one_day_ago=$(date -d "1 day ago" +%s)
  # only get files from at least a day ago to prevent races
  echo "$LAST_CONTAINERLIST" | xmlstarlet sel -t -m "//Blob" -v "Name" -o "|" -v "Properties/Last-Modified" -n | while IFS='|' read -r blob_name last_modified; do
    last_modified_ts=$(date -d "$last_modified" +%s)

    if [ "$last_modified_ts" -le "$one_day_ago" ]; then
        echo "$blob_name"
    fi
  done
}

function azureContainerFileDelete() {
    local ABSURL="$1"
    local SASTKN="$2"
    local FILENAME="$3"

    if [ "${DRY_RUN}" == "1" ]; then
      echo "dry-run: would delete ${ABSURL}/${FILENAME}"
    else
      curl -f -X DELETE "${ABSURL}/${FILENAME}?${SASTKN}" -H "x-ms-version: 2020-10-02"
    fi
}
function getFilesToRemove() {
  local LIST1="$1"
  local LIST2="$2"

  echo "$LIST1" | sort > /tmp/list1.txt
  echo "$LIST2" | sort > /tmp/list2.txt

  local MISSINGFILES
  MISSINGFILES=$(comm -13 /tmp/list1.txt /tmp/list2.txt)
  rm /tmp/list1.txt
  rm /tmp/list2.txt

  echo "${MISSINGFILES}"
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi
ARTSTORE="$1"
ARTSTORE_FILENAME="${HOME}/.kosbuild/artifactstores/${ARTSTORE}.json"
shift

# delete flag check
[ "$1" == "--delete" ] && DRY_RUN=0

if [ ! -f "${ARTSTORE_FILENAME}" ]; then
  echo "error: no artifact store found (${ARTSTORE_FILENAME})"
  exit 1
fi

# get variables from artifactstore
ARTSTORE_TYPE="$(jq -r '.type' "${ARTSTORE_FILENAME}")"
if [ "${ARTSTORE_TYPE}" != "azurecontainer" ]; then
  echo "error: $0 only supports azurecontainer type repos"
  exit 1
fi
IS_MARKET="$(jq -r '.marketplace' "${ARTSTORE_FILENAME}")"
[ "${IS_MARKET}" != "true" ] && IS_MARKET="false"
APIKEY="$(jq -r '.["studio-apikey"]' "${ARTSTORE_FILENAME}")"
[ "${APIKEY}" == "null" ] && echo "invalid apikey on repo ${ARTSTORE}. Exiting..." && exit 1
STUDIO_SERVER_COUNT=$(jq '.additional_publish_servers | length' ${ARTSTORE_FILENAME})
CONTAINER="$(jq -r '.["container"]' "${ARTSTORE_FILENAME}")"
SASTOKEN="$(jq -r '.["sastoken"]' "${ARTSTORE_FILENAME}")"
if [ "${CONTAINER}" == "null" ] || [ "${SASTOKEN}" == "null" ]; then
  echo "ERROR: container or sastoken is null"
  exit 1
fi

echo "query studio server ${DEFAULT_STUDIO_SERVER} for artifacts in ${ARTSTORE}"
[ "${IS_MARKET}" == "true" ] && STUDIO_INSTANCES=$(getMarketArtifactInstances "${DEFAULT_STUDIO_SERVER}" "${ARTSTORE}" "${APIKEY}" "${CONTAINER}")
[ "${IS_MARKET}" == "false" ] && STUDIO_INSTANCES=$(getNonmarketArtifactInstances "${DEFAULT_STUDIO_SERVER}" "${ARTSTORE}" "${APIKEY}" "${CONTAINER}")

if [ $STUDIO_SERVER_COUNT -ne 0 ]; then
  for j in $( eval echo {0..$((STUDIO_SERVER_COUNT-1))} ); do
    SERVER=$(jq -r ".additional_publish_servers[$j].server" ${ARTSTORE_FILENAME})
    SERVER="${SERVER/wss:\/\//https:\/\/}"
    echo "query additional studio server ${SERVER} for artifacts in ${ARTSTORE}"
    [ "${IS_MARKET}" == "true" ] && STUDIO_INSTANCES_ADD=$(getMarketArtifactInstances "${SERVER}" "${ARTSTORE}" "${APIKEY}" "${CONTAINER}")
    [ "${IS_MARKET}" == "false" ] && STUDIO_INSTANCES_ADD=$(getNonmarketArtifactInstances "${SERVER}" "${ARTSTORE}" "${APIKEY}" "${CONTAINER}")
    STUDIO_INSTANCES="${STUDIO_INSTANCES}${STUDIO_INSTANCES_ADD}"
  done
fi
CONTAINER_FILES=$(getAzureStorageFileList "${CONTAINER}" "${SASTOKEN}")
GARBAGE_FILES="$(getFilesToRemove "${STUDIO_INSTANCES}" "${CONTAINER_FILES}")"
CONTAINER_FILES_COUNT=$(echo "${CONTAINER_FILES}" | wc -w)
GARBAGE_FILES_COUNT=$(echo "${GARBAGE_FILES}" | wc -w)
CONTAINER_FILES_REMAINING=$(echo $(($CONTAINER_FILES_COUNT-$GARBAGE_FILES_COUNT)))

for GC_FILE in ${GARBAGE_FILES}; do
   echo "delete unreferenced file ${GC_FILE}"
   azureContainerFileDelete "${CONTAINER}" "${SASTOKEN}" "${GC_FILE}"
done

echo "Number of files in container: ${CONTAINER_FILES_COUNT}"
echo "Number of files to garbage-collect : ${GARBAGE_FILES_COUNT}"
echo "Files remaining: ${CONTAINER_FILES_REMAINING}"

