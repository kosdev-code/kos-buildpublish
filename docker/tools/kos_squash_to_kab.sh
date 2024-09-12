#! /bin/bash

set -e -o pipefail

if [ $# -lt 3 ]; then
echo "usage: $0 <squash file> <output kab> <KAB version> [descriptor.json path]"
echo "  packages the squash file as a KAB"
echo "  if KAB_TAG is specified in the environment, it will be applied to the KAB file"
exit 1
fi

SQUASHFILE="$1"
KABFILE="$2"
VERSION="$3"
DESCRIPTOR="$4"

kos_make_layer_kab.sh "${SQUASHFILE}" "${KABFILE}" "${VERSION}" "kos.layer" ${DESCRIPTOR}
