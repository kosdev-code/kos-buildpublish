#! /bin/bash
set -e -o pipefail

# This script handles the kos publish process, given a kosbuild json file.
# Inputs:
#   - <build definition json file> drives the publish process

function usage() {
    echo "usage: $0 [kos build json file]"
}

BUILD_DEF=$1

# artifact fail policy:
#   set to hard if we should raise an error if the artifact is not found
#   set to soft if we should warn if the artifact is not found, but continue
ARTIFACT_FAIL_POLICY="hard"

if [ "${BUILD_DEF}" == "" ] && [ "${KOSBUILD_BUILD_DEFINITION}" != "" ]; then
BUILD_DEF="${KOSBUILD_BUILD_DEFINITION}"
fi


if [ ! -f "${BUILD_DEF}" ]; then
  echo "Error: build definition not found: (${CFGFILE})"
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
        #--server="http://host.docker.internal:8080" add this for local testing
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


# Given a filename regex, this function will return the actual file that is resolved
#  it ensures that exactly 1 file resolves and places the filename in FILE_TO_PUBLISH
#  if the file does not exist, FILE_TO_PUBLISH is set to ""
function get_filename() {
  FILENAME_SEARCH="$1"

  export KOS_STD_VERSION_REGEX="[0-9]+\.[0-9]+\.[0-9]+(-SNAPSHOT)?"
  local FILENAME_DIR
  local FILELIST
  local FILECOUNT

  eval FILENAME_SEARCH="${FILENAME_SEARCH}"
  FILENAME_DIR=$( dirname "${FILENAME_SEARCH}" )
  FILELIST=$(find "${FILENAME_DIR}" -type f | grep -E "${FILENAME_SEARCH}" || true)
  if [ "${FILELIST}" == "" ]; then
    FILECOUNT=0
    FILE_TO_PUBLISH=""
    return
  else
    FILECOUNT="$(echo "$FILELIST" | wc -l)"
  fi
  if [ "$FILECOUNT" != "1" ]; then
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

  #echo "$0: KAB Version/Tag: $KABVERSION/$KABTAG"
  #REMOTE_FILENAME="${ARTIFACTNAME}_${KABTAG}_${KABVERSION}_${KABHASH}${EXTENSION}"
  echo "$0: KAB Version: $KABVERSION"
  REMOTE_FILENAME="${ARTIFACTNAME}_${KABTAG}${KABVERSION}_${KABHASH}${EXTENSION}"

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
  for i in $( eval echo "{0..$((ARTIFACT_COUNT-1))}" ); do
    art_id=$(jq -r ".artifacts[$i].id" "${CFGFILE}")
    art_filename=$(jq -r ".artifacts[$i].filename" "${CFGFILE}")
    art_artstore=$(jq -r ".artifacts[$i].artifactstore" "${CFGFILE}")
    art_qualifier=$(jq -r ".artifacts[$i].qualifier" "${CFGFILE}")
    REMOTE_FILENAME="$(jq -r ".artifacts[$i].remote_filename" "${CFGFILE}")"

    # if qualifier is unset, it's any
    if [[ "${art_qualifier}" == "null" ]]; then
    art_qualifier="any"
    fi

    # remote_filename is optional, so if it's not set, then blank it out
    if [[ "${REMOTE_FILENAME}" == "null" ]]; then
      REMOTE_FILENAME=""
    fi


    echo
    echo "-- kos-publish --"
    echo "$0 ${art_id} [${art_qualifier}] : ${art_filename}, ${art_artstore}"
    # getFilename populates FILE_TO_PUBLISH with the exact file we're going to publish
    get_filename "${art_filename}"

    # check file
    if [ "${FILE_TO_PUBLISH}" == "" ]; then
       if [ "${ARTIFACT_FAIL_POLICY}" == "soft" ]; then
          echo "WARNING: ${art_filename} not found.  Skipping due to soft failure policy..."
          continue
       fi
    fi

    # determine the remote filename, populating REMOTE_FILENAME
    [ "${REMOTE_FILENAME}" == "" ] && getRemoteFilename "${art_id}" "${FILE_TO_PUBLISH}"

    # upload the artifact to the repo
    kos_upload_artifact "${FILE_TO_PUBLISH}" "${art_artstore}" "${REMOTE_FILENAME}"

    publish_artifact "${art_id}" "${art_qualifier}" "${FILE_TO_PUBLISH}" "${art_artstore}" "${REMOTE_FILENAME}"
  done

}

###  SHELL SCRIPT starts here:
echo "******** PUBLISH *********"
if [ "${KOSBUILDER_DEV}" == "1" ]; then
  echo "Publish: KOSBUILDER_DEV is set, indicating a developer environment.  Publish is disabled for developer environments"
  echo "set KOSBUILDER_DEV to 0 if you wish to override"
  exit 1
fi
export BUILD_DEFINITION="${BUILD_DEF}"
echo " => ${BUILD_DEFINITION}"

PREPUBLISH_CMD=$(jq -r ".prepublish_cmd" "${BUILD_DEF}")
if [ "${PREPUBLISH_CMD}" != "null" ]; then
  echo "~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~"
  echo "kos_publish_automation.sh: pre-publish with command ${PREPUBLISH_CMD}"
  ${PREPUBLISH_CMD}
fi

# ARTIFACT_FAIL_POLICY may be hard or soft, defaults to hard
ARTIFACT_FAIL_POLICY=$(jq -r ".artifact_fail_policy" "${BUILD_DEF}")
case $ARTIFACT_FAIL_POLICY in
  hard)
    ;;
  soft)
    ;;
  *)
    ARTIFACT_FAIL_POLICY="hard"
    ;;
esac

echo "~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~"
publish_artifact_per_configfile "${BUILD_DEF}"

POSTPUBLISH_CMD=$(jq -r ".postpublish_cmd" "${BUILD_DEF}")
if [ "${POSTPUBLISH_CMD}" != "null" ]; then
  echo "~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~"
  echo "kos_publish_automation.sh: post-publish with command ${POSTPUBLISH_CMD}"
  ${POSTPUBLISH_CMD}
fi
