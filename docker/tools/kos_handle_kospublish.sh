#! /bin/bash
set -e -o pipefail

PROGNAME="$(basename $0)"
ORIG_PATH="$(pwd)"
KOSPUBLISH_FILE="$1"

# This script handles the kos publish process, given a kospublish json file.
# Inputs:
#   $PROGNAME <kospublish file> 

function usage() {
    echo "usage: $PROGNAME [kospublish file]"
}


# Given an artifact name and KAB file, this function determines the remote filename that should be published
# New Variables: REMOTE_FILENAME
function getRemoteFilename() {
  local ARTIFACTNAME="$1"
  local KABFILE="$2"
  local KABTAG="$3"

  local KABVERSION
  local KABHASH
  # get the version from the kabfile by using kabtool
  KABVERSION=$(kabtool -l "${KABFILE}" |grep -m 1 'Version' | cut -d ':' -f2 )
  # get the hash
  KABHASH=$(sha256sum "${KABFILE}" | cut -d " " -f 1)

  # trim the space on either side of variables:
  KABVERSION=$(echo "${KABVERSION}" | sed 's/[[:space:]]*//;s/[[:space:]]*$//')
  KABTAG=$(echo "${KABTAG}" | sed 's/[[:space:]]*//;s/[[:space:]]*$//')

  #replace commas and spaces in tag with underscores
  KABTAG="${KABTAG//,/_}"
  KABTAG="${KABTAG// /_}"

  # if kabtag is not empty, give it an underscore
  if [ "${KABTAG}" != "" ]; then
    KABTAG="${KABTAG}_"
  fi

  # mirror the extension of the original file, or if it has no extension, then there is no extension to extract and we'll leave it alone
  local EXTENSION
  case $KABFILE in
  *.*) EXTENSION=".${KABFILE##*.}";;
  *) EXTENSION=""
  esac

  echo "KAB Version: $KABVERSION"
  REMOTE_FILENAME="${ARTIFACTNAME}_${KABTAG}${KABVERSION}_${KABHASH}${EXTENSION}"

  echo "remote filename: ${REMOTE_FILENAME}"
}

# function to publish the artifact to studio server
function publish_artifact() {
    local ID="$1"
    local ART_QUALIFIER="$2"
    local FILENAME="$3"
    local REPO="$4"
    local REMOTE_FILENAME="$5"

    ARTSTORE_FILENAME="$HOME/.kosbuild/artifactstores/${REPO}.json"
    # get the container and token
    ARTSTORE_APIKEY="$(jq -r '.["studio-apikey"]' "${ARTSTORE_FILENAME}")"
    ARTSTORE_MARKETPLACE="$(jq -r '.["marketplace"]' "${ARTSTORE_FILENAME}")"
    if [ "${ARTSTORE_MARKETPLACE}" == "true" ]; then
        IS_MARKETPLACE="--marketplace"
    else
        unset IS_MARKETPLACE
    fi

    echo "publish artifact: ${ID}, ${ART_QUALIFIER}, ${FILENAME}, ${REPO} ${REMOTE_FILENAME}"

    # default publish
    if [ "${ARTSTORE_APIKEY}" == "null" ]; then
       echo "WARNING: no studio-apikey specified.  Skipping default publish"
    else
      publishtool -a "${ARTSTORE_APIKEY}" -n "${ID}" -q "${ART_QUALIFIER}" -r "${REPO}" -l "${REMOTE_FILENAME}" ${IS_MARKETPLACE} "${FILENAME}"
      echo
    fi

    local SERVER_COUNT
    SERVER_COUNT=$(jq '.additional_publish_servers | length' ${ARTSTORE_FILENAME})
    local j
    if [ $SERVER_COUNT -ne 0 ]; then
      for j in $( eval echo "{0..$((SERVER_COUNT-1))}" ); do
        local SERVER
        local SERVER_API_KEY

        # handle additional publish servers
        SERVER=$(jq -r ".additional_publish_servers[$j].server" "${ARTSTORE_FILENAME}")
        SERVER_API_KEY=$(jq -r ".additional_publish_servers[$j].apikey" "${ARTSTORE_FILENAME}")
        if [ "${SERVER_API_KEY}" == "null" ] && [ "${ARTSTORE_APIKEY}" != "null" ]; then
           SERVER_API_KEY="${ARTSTORE_APIKEY}"
        fi

        # publish to the additional server
        if [ "${SERVER_API_KEY}" != "null" ]; then
          echo "-- publish artifact to ${SERVER} -- "
          publishtool --server="${SERVER}" -a "${SERVER_API_KEY}" -n "${ID}" -q "${ART_QUALIFIER}" -r "${REPO}" -l "${REMOTE_FILENAME}" ${IS_MARKETPLACE} "${FILENAME}"
          echo
        fi
      done
    fi
}


# check args
if [ ! -f "${KOSPUBLISH_FILE}" ]; then  
  usage
  exit 1
fi

# extract data from the kospublish file
ID="$(jq -r ".id" "${KOSPUBLISH_FILE}")"
KAB="$(jq -r ".kab" "${KOSPUBLISH_FILE}")"
TAGS="$(jq -r ".tags // empty" "${KOSPUBLISH_FILE}")"
ARTIFACTSTORE="$(jq -r ".artifactstore" "${KOSPUBLISH_FILE}")"

# sanity checks
if [[ "$ID" == "null" || "$KAB" == "null" || "$ARTIFACTSTORE" == "null" ]]; then
  echo "$PROGNAME ERROR: null field in kospublish file [ id=$ID, kab=$KAB, artifactstore=$ARTIFACTSTORE ]"
  exit 1
fi
# blank tags means any
if [ "$TAGS" == "" ]; then
  TAGS="any"
fi

# go to the directory where the publish file is since everything will be relative to that
cd "$(dirname "$KOSPUBLISH_FILE")"

echo "~~$PROGNAME~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "publishing $KAB from $(pwd)"

# get the remote filename, it's going to be stored in REMOTE_FILENAME
getRemoteFilename "$ID" "$KAB" "$TAGS"

# only publish if automation check is bypassed or github actions is true
if [[ "$AUTOMATION_CHECK_BYPASS" == "1" || "$GITHUB_ACTIONS" == "true" || "$USER" == "buildbot" ]]; then 
  # now, upload the file to the artifactstore
  kos_upload_artifact "${KAB}" "${ARTIFACTSTORE}" "${REMOTE_FILENAME}"

  # register the artifact with the Studio Server
  publish_artifact "$ID" "$TAGS" "$KAB" "$ARTIFACTSTORE" "$REMOTE_FILENAME"
else 
  echo "WARNING: Automation not detected.  bypassing upload/publish."
  echo "   set AUTOMATION_CHECK_BYPASS=1 to bypass check"
fi
