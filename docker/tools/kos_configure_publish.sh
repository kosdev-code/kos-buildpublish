#! /bin/bash

# this script will configure an artifact to be published by writing a .kospublish file
# next to the kab.  Additional tooling can be used then to actually publish according
# to the kospublish file.
#
# This script is intended to be run as part of automation and may have limited uses when manually run
#
#  command line arguments are passed including id, kab, tags, and artstore to set the parameters
#  of the KAB.  This tool will prioritize the use though of a kospublish.json file in the directory
#  from where it's run.  The kospublish.json file MUST be present in the directory in order for this
#  tool to actually write the kospublish file.
set -e -o pipefail
PROGNAME="$(basename $0)"

ID=""
KAB=""
TAGS=""
ARTSTORE=""

FILE_PUBLISH_DETAILS="kospublish.json"

if [ ! -f "${FILE_PUBLISH_DETAILS}" ]; then
  echo "$PROGNAME: no publish file found."
  exit 0
fi

while [[ $# -gt 0 ]]; do
  if [[ "$2" == --* ]]; then
    echo "$PROGNAME error- invalid argument $2"
    exit 1
  fi

    case "$1" in
      --id)
          ID="$2"
          shift 2
          ;;
      --kab)
          KAB="$2"
          shift 2
          ;;
      --tags)
          TAGS="$2"
          shift 2
          ;;
      --artstore)
          ARTSTORE="$2"
          shift 2
          ;;
      --)
        shift
        break
        ;;
      *)
        echo "$0 Error parsing options $1"
        exit 1
        ;;
    esac
done

# the local publishing details file has priority over the command line arguments
TMP="$(jq -r ".id // empty" "${FILE_PUBLISH_DETAILS}")"
[ "$TMP" != "" ] && ID="$TMP"
TMP="$(jq -r ".artifactstore // empty" "${FILE_PUBLISH_DETAILS}")"
[ "$TMP" != "" ] && ARTSTORE="$TMP"
TMP="$(jq -r ".tags // empty" "${FILE_PUBLISH_DETAILS}")"
[ "$TMP" != "" ] && TAGS="$TMP"
TMP="$(jq -r ".kab // empty" "${FILE_PUBLISH_DETAILS}")"
[ "$TMP" != "" ] && KAB="$TMP"

if [[ "$KAB" == "" || "$ID" == "" || "$TAGS" == "" || "$ARTSTORE" == "" ]]; then
   echo "$PROGNAME  ERROR: not enough detail for publish"
   echo "  KAB: $KAB"
   echo "  ID: $ID"
   echo "  TAGS: $TAGS"
   echo "  ARTIFACTSTORE: $ARTSTORE"
   exit 1
fi

if [ ! -f "${KAB}" ]; then
  echo "$PROGNAME ERROR: KAB file $KAB not found "
  exit 1
fi

KABPATH="$(dirname "$KAB")"
KAB="$(basename "${KAB}")"

# kospublish file goes next to the KAB file, dropping the .kab extension and replacing with the .kospublish extension
KOSPUBLISH_FILE="${KABPATH}/${KAB%.kab}.kospublish"
rm -f "${KOSPUBLISH_FILE}"

# build kospublish file
jq -n --arg id "${ID}" --arg kab "${KAB}" --arg tags "${TAGS}" --arg artstore "${ARTSTORE}" \
   '{ "id": $id, "kab": $kab, "tags": $tags, "artifactstore": $artstore }' > "${KOSPUBLISH_FILE}"
