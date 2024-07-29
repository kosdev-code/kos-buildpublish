#! /bin/bash

set -e -o pipefail

if [ $# -lt 3 ]; then
echo "usage: $0 <squash file> <output kab> <KAB version>"
echo "  packages the squash file as a KAB"
exit 1
fi

SQUASHFILE="$1"
KABFILE="$2"
VERSION="$3"

# make a temporary directory
TMPDIR="$(mktemp -d)"
# the squash becomes layer.img
cp "${SQUASHFILE}" "${TMPDIR}/layer.img"

# now, create the KAB
pushd "${TMPDIR}"
zip -Z store tmp.zip layer.img
kabtool -b -t kos.layer -v "${VERSION}" -z tmp.zip layer.kab
popd

# put the KAB where it needs to go and remove temporary files
cp "${TMPDIR}/layer.kab" "${KABFILE}"
rm -rf "${TMPDIR}"

