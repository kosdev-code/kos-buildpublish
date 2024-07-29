#! /bin/bash

set -e -o pipefail

if [ $# -lt 3 ]; then
echo "usage: $0 <squash file> <output kab> <KAB version> [descriptor.json path]"
echo "  packages the squash file as a KAB"
exit 1
fi

SQUASHFILE="$1"
KABFILE="$2"
VERSION="$3"
DESCRIPTOR="$4"

# make a temporary directory
TMPDIR="$(mktemp -d)"
# the squash becomes layer.img
cp "${SQUASHFILE}" "${TMPDIR}/layer.img"

# include the descriptor if it exists
if [ ! -z "${DESCRIPTOR}" ]; then
  cp "${DESCRIPTOR}" "${TMPDIR}/descriptor.json"
fi

# now, create the KAB
pushd "${TMPDIR}"
zip -Z store tmp.zip layer.img
# add descriptor if we have it.
[ ! -z "${DESCRIPTOR}" ] && zip -Z store descriptor.json
kabtool -b -t kos.layer -v "${VERSION}" -z tmp.zip layer.kab
popd

# put the KAB where it needs to go and remove temporary files
cp "${TMPDIR}/layer.kab" "${KABFILE}"
rm -rf "${TMPDIR}"

