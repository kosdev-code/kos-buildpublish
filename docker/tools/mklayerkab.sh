#! /bin/bash

# this script creates a kab based on the details from the command line arguments or in the file layerkab.cfg
# {
#   "input": "../../output/squash/kos-layer-boardconf.squash",
#   "output": "../../output/kab/",
#   "version": "0.0.0-SNAPSHOT",
#   "qualifier": "raspberrypi4",
#   "kabtype": "kos.layer",
#   "descriptor": "descriptor.json"
# }
#  In the above layerkab, it would use the INPUT squash to create a KAB
#  of type kos.layer.  The kab would be tagged with raspberrypi4 and it would
#  be placed in the output directory (because of the trailing slash)
#
#  If version is unspecified, it must be specified in the environment as KAB_VERSION
#  If kabtype is unspecified, it defaults to kos.layer
#  if output is unspecified, it defaults to $input.kab
#  descriptor is optional- if unspecified, it MAY be specified in the enviuroment as KAB_DESCRIPTOR
#
#  output can also specify an exact filename (without trailing slash)
#  A Keyset is required for signing.  It will default to the org you're signed into with KOS STUDIO
#    or as specified by the $HOME/kosStudio/tools.properties
#
# This script is useful primarily in automation scenarios, but may also be useful for demonstration purposes
# It assumes that kabtool is in your path.

PROGNAME="$(basename $0)"

if [ $# -eq 0 ]; then
  KABCFG=layerkab.cfg
  if [ ! -f "${KABCFG}" ]; then
    echo "error: $PROGNAME needs $KABCFG"
    exit 1
  fi

  INPUT="$(jq -r ".input // empty" "$KABCFG")"
  QUALIFIER="$(jq -r ".qualifier // empty" "$KABCFG")"
  KABTYPE="$(jq -r ".kabtype // empty" "$KABCFG")"
  VERSION="$(jq -r ".version // empty" "$KABCFG")"
  DESCRIPTOR="$(jq -r ".descriptor // empty" "$KABCFG")"
  OUTPUT="$(jq -r ".output // empty" "$KABCFG")"
else
  while [[ $# -gt 0 ]]; do
    if [[ "$2" == --* ]]; then
      echo "$PROGNAME error- invalid argument $2"
      exit 1
    fi

    case "$1" in
      --in)
          INPUT="$2"
          shift 2
          ;;
      --out)
          OUTPUT="$2"
          shift 2
          ;;
      --type)
          KABTYPE="$2"
          shift 2
          ;;
      --tags)
          QUALIFIER="$2"
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
fi

set -e -o pipefail

# get the version from the environment if not specified
if [ "${VERSION}" == "" ]; then
  VERSION="$KAB_VERSION"
fi

if [ "${KABTYPE}" == "" ]; then
  KABTYPE="kos.layer"
fi
if [[ "$KABTYPE" != "kos.layer"* ]]; then
  echo "error: KABTYPE does not begin with kos.layer"
  exit 1
fi

INPUT="$(realpath "$INPUT")"
# make sure the file exists
if [ ! -f "${INPUT}" ]; then
  echo "error ($PROGNAME): squash file ${INPUT} not found"
  exit 1
fi

if [ "$OUTPUT" == "" ]; then
  OUTPUT="$INPUT.kab"
else
  if [[ "$OUTPUT" == *"/" ]]; then
     OUTPUT="$OUTPUT$(basename "$INPUT").kab"
  fi
fi

if [ "${DESCRIPTOR}" != "" ]; then
  DESCRIPTOR="$(realpath "${DESCRIPTOR}")"
  if [ ! -f "${DESCRIPTOR}" ]; then
    echo "error ($PROGNAME): descriptor file not found"
    exit 1
  fi
else
  DESCRIPTOR="${KAB_DESCRIPTOR}"
fi

if [ "${VERSION}" == "" ]; then
  echo "error ($PROGNAME): version not specified (in either configuration or environment)"
  exit 1
fi

# create a temporary directory for the KAB
TMPLAYER_DIR="$(mktemp -d)"
# cleanup logic
function cleanup() {
    rm -rf "${TMPLAYER_DIR}"
}
trap cleanup EXIT

cp "$INPUT" "${TMPLAYER_DIR}/layer.img"

# include the descriptor
if [ "$DESCRIPTOR" != "" ]; then
  cp "$DESCRIPTOR" "${TMPLAYER_DIR}/descriptor.json"
fi

echo "$PROGNAME: create KAB: $OUTPUT"
echo "$PROGNAME:   from $INPUT, type $KABTYPE, version ${VERSION}"
mkdir -p "$(dirname "${OUTPUT}")"

kabtool -b -t "${KABTYPE}" -v "${VERSION}" --tag "${QUALIFIER}" -dir "${TMPLAYER_DIR}" "$OUTPUT"
