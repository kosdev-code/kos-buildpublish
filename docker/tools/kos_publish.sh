#! /bin/bash
set -e -o pipefail

# This script handles the kos publish process, given a kosbuild json file.
# Inputs:
#   - <build definition json file> drives the publish process

function usage() {
    echo "usage: $0 <kos build json file>"
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

BUILD_DEF=$1

if [ ! -f "${BUILD_DEF}" ]; then
  usage
  exit 1
fi

# function to publish the artifact to studio server
function publish_artifact() {
    local ID="$1"
    local ART_QUALIFIER="$2"
    local FILENAME="$3"
    local REPO="$4"
    local REMOTE_FILENAME="$5"
    local IS_MARKETPLACE="$6"

    if [ $IS_MARKETPLACE -eq 1 ]; then
        IS_MARKETPLACE="--marketplace"
    else
        unset IS_MARKETPLACE
    fi
    ARTSTORE_FILENAME="$HOME/.kosbuild/artifactstores/${REPO}.json"
    # get the container and token
    ARTSTORE_APIKEY="$(jq -r '.["studio-apikey"]' "${ARTSTORE_FILENAME}")"

    echo "publish artifact: ${ID}, ${ART_QUALIFIER}, ${FILENAME}, ${REPO} ${REMOTE_FILENAME}"

    # default publish
    if [ "${ARTSTORE_APIKEY}" == "null" ]; then
       echo "WARNING: no studio-apikey specified.  Skipping default publish"
    else
      # skip publishtool hack
      publishtool -a "${ARTSTORE_APIKEY}" -n "${ID}" -q "${ART_QUALIFIER}" -r "${REPO}" -l "${REMOTE_FILENAME}" ${IS_MARKETPLACE} "${FILENAME}"
      echo
    fi

    local SERVER_COUNT 
    SERVER_COUNT=$(jq '.additional_publish_servers | length' ${ARTSTORE_FILENAME})
    local j
    if [ $SERVER_COUNT -ne 0 ]; then
      for j in $( eval echo {0..$((SERVER_COUNT-1))} ); do
        local SERVER
        local SERVER_API_KEY

        # handle additional publish servers
        SERVER=$(jq -r ".additional_publish_servers[$j].server" ${ARTSTORE_FILENAME})
        SERVER_API_KEY=$(jq -r ".additional_publish_servers[$j].apikey" ${ARTSTORE_FILENAME})
        if [ "${SERVER_API_KEY}" == "null" ] && [ "${ARTSTORE_API_KEY}" != "null" ]; then
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


# Given a filename regex, this function will return the actual file that is resolved
#  it ensures that exactly 1 file resolves and places the filename in FILE_TO_PUBLISH
function get_filename() {
  FILENAME_SEARCH="$1"
  local FILENAME_DIR="$(dirname "${FILENAME_SEARCH}")"

  export KOS_STD_VERSION_REGEX="[0-9]+\.[0-9]+\.[0-9]+(-SNAPSHOT)?"
  local FILENAME_DIR
  local FILELIST
  local FILECOUNT

  eval FILENAME_SEARCH=${FILENAME_SEARCH}
  FILENAME_DIR=$( dirname "${FILENAME_SEARCH}" )
  FILELIST=$(find "${FILENAME_DIR}" -type f | grep -E "${FILENAME_SEARCH}")
  FILECOUNT=$(echo "$FILELIST" | wc -l )
  if [ $FILECOUNT != 1 ]; then
     echo "error: found ${FILECOUNT} files with ${FILENAME_SEARCH}, need exactly 1"
     exit 1
  fi
  FILE_TO_PUBLISH="${FILELIST}"
}

# Given an artifact name and KAB file, this function determines the remote filename that should be published
function getRemoteFilename() {
  local ARTIFACTNAME="$1"
  local KABFILE="$2"

  local KABVERSION
  local KABTAG
  local KABHASH
  # get the version and the tag from the kabfile by using kabtool
  KABVERSION=$(kabtool -l "${KABFILE}" |grep -m 1 'Version' | cut -d ':' -f2 )
  KABTAG=$(kabtool -l "${KABFILE}" |grep -m 1 'Tag' | cut -d ':' -f2 )
  # get the hash
  KABHASH=$(sha256sum "${KABFILE}" | cut -d " " -f 1)

  # trim the space on either side of variables:
  KABVERSION=$(echo "${KABVERSION}" | sed 's/[[:space:]]*//;s/[[:space:]]*$//')
  KABTAG=$(echo "${KABTAG}" | sed 's/[[:space:]]*//;s/[[:space:]]*$//')

  # if kabtag is empty, then replace with unknown
  if [ "${KABTAG}" == "" ]; then
  KABTAG="unknown"
  fi

  # Check if the KABTAG contains any spaces or comma characters
  if [[ "${KABTAG}" =~ [[:space:]]|, ]] ; then
      # not sure how to build filename if we have spaces or commas
      echo "$0 error- tag contains spaces or commas: ${KABTAG}"
      exit 1
  fi


  # mirror the extension of the original file, or if it has no extension, then there is no extension to extract and we'll leave it alone
  local EXTENSION
  case $KABFILE in
  *.*) EXTENSION=".${KABFILE##*.}";;
  *) EXTENSION=""
  esac

  #echo "$0: KAB Version/Tag: $KABVERSION/$KABTAG"
  #REMOTE_FILENAME="${ARTIFACTNAME}_${KABTAG}_${KABVERSION}_${KABHASH}${EXTENSION}"
  echo "$0: KAB Version: $KABVERSION"
  REMOTE_FILENAME="${ARTIFACTNAME}_${KABVERSION}_${KABHASH}${EXTENSION}"

  echo "remote filename: ${REMOTE_FILENAME}"
}

function publish_artifact_per_configfile() {
  local CFGFILE="$1"
  # get a count of artifacts to process
  ARTIFACT_COUNT=$(cat "${CFGFILE}" | jq '.artifacts | length')
  if [ $ARTIFACT_COUNT -eq 0 ]; then
    echo "no artifacts defined."
    exit 0
  fi

  # for each artifact
  for i in $( eval echo {0..$((ARTIFACT_COUNT-1))} ); do
    art_id=$(jq -r ".artifacts[$i].id" "${CFGFILE}")
    art_filename=$(jq -r ".artifacts[$i].filename" "${CFGFILE}")
    art_artstore=$(jq -r ".artifacts[$i].artifactstore" "${CFGFILE}")
    art_qualifier=$(jq -r ".artifacts[$i].qualifier" "${CFGFILE}")
    art_marketplace=$(jq -r ".artifacts[$i].marketplace" "${CFGFILE}")

    # if qualifier is unset, it's any
    if [[ "${art_qualifier}" == "null" ]]; then
    art_qualifier="any"
    fi
    # if marketplace is unset, it's any
    if [[ "${art_marketplace}" == "null" ]]; then
    art_marketplace=0
    fi


    echo
    echo "-- kos-publish --"
    echo "$0 ${art_id} [${art_qualifier}] : ${art_filename}, ${art_artstore}"
    # getFilename populates FILE_TO_PUBLISH with the exact file we're going to publish
    get_filename "${art_filename}"

    # determine the remote filename, populating REMOTE_FILENAME
    getRemoteFilename "${art_id}" "${FILE_TO_PUBLISH}"

    # upload the artifact to the repo
    kos_upload_artifact "${FILE_TO_PUBLISH}" "${art_artstore}" "${REMOTE_FILENAME}"

    publish_artifact "${art_id}" "${art_qualifier}" "${FILE_TO_PUBLISH}" "${art_artstore}" "${REMOTE_FILENAME}" ${art_marketplace}
  done

}

###  SHELL SCRIPT starts here:
export BUILD_DEFINITION="${BUILD_DEF}"
PREPUBLISH_CMD=$(jq -r ".prepublish_cmd" "${BUILD_DEF}")
if [ "${PREPUBLISH_CMD}" != "null" ]; then
  echo "kos_publish.sh: pre-publish with command ${PREPUBLISH_CMD}"
  ${PREPUBLISH_CMD}
fi

publish_artifact_per_configfile "${BUILD_DEF}"

POSTPUBLISH_CMD=$(jq -r ".postpublish_cmd" "${BUILD_DEF}")
if [ "${POSTPUBLISH_CMD}" != "null" ]; then
  echo "kos_publish.sh: post-publish with command ${POSTPUBLISH_CMD}"
  ${POSTPUBLISH_CMD}
fi
