#! /bin/bash

set -e -o pipefail

if [ $# -lt 4 ]; then
echo "usage: $0 <input file> <output kab> <KAB version> <KAB type> [descriptor.json path]"
echo "  packages the squash file as a KAB"
echo "  if KAB_TAG is specified in the environment, it will be applied to the KAB file"
exit 1
fi

INFILE="$1"
KABFILE="$2"
VERSION="$3"
KABTYPE="$4"
DESCRIPTOR="$5"

# make a temporary directory
TMPDIR="$(mktemp -d)"
# the squash becomes layer.img
cp "${INFILE}" "${TMPDIR}/layer.img"

# include the descriptor if it exists
if [ ! -z "${DESCRIPTOR}" ]; then
  cp "${DESCRIPTOR}" "${TMPDIR}/descriptor.json"
fi

# now, create the KAB
pushd "${TMPDIR}"
zip -Z store tmp.zip layer.img
# add descriptor if we have it.
[ ! -z "${DESCRIPTOR}" ] && zip -Z store tmp.zip descriptor.json

if [ "${KAB_TAG}" != "" ]; then
  kabtool -b -t "${KABTYPE}" -v "${VERSION}" -q "${KAB_TAG}" -z tmp.zip layer.kab
else
  kabtool -b -t "${KABTYPE}" -v "${VERSION}" -z tmp.zip layer.kab
fi
popd

# put the KAB where it needs to go and remove temporary files
cp "${TMPDIR}/layer.kab" "${KABFILE}"
rm -rf "${TMPDIR}"

