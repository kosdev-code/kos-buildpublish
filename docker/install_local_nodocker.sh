#! /bin/bash

THIS_SCRIPT=$(realpath "$0")
THIS_SCRIPT_DIR=$(dirname "$THIS_SCRIPT")

set -e -o pipefail

echo "install kos_buildpublish for non-docker use case"
echo "  this script assumes that you already have the dependencies needed on your system"

LOCALBIN="$HOME/.local/bin"
mkdir -p "${LOCALBIN}"


cp -r "${THIS_SCRIPT_DIR}/tools/." "${LOCALBIN}"
cp "${THIS_SCRIPT_DIR}/kos_build_handler.sh" "${LOCALBIN}"
chmod +x "${LOCALBIN}/load_secrets.sh" "${LOCALBIN}/kos_"* "${LOCALBIN}/kabtool" "${LOCALBIN}/publishtool"

sed -i 's|/usr/local/lib|'"${LOCALBIN}"'|g' "${LOCALBIN}/kabtool"
sed -i 's|/usr/local/lib|'"${LOCALBIN}"'|g' "${LOCALBIN}/publishtool"

# need to install azcopy
AZCOPY_VERSION=10.25.1
case $(uname -m) in \
    x86_64) \
        curl -L https://azcopyvnext.azureedge.net/releases/release-${AZCOPY_VERSION}-20240612/azcopy_linux_amd64_${AZCOPY_VERSION}.tar.gz | tar -xvz --strip-components=1 -C "$LOCALBIN" azcopy_linux_amd64_$AZCOPY_VERSION/azcopy; \
        ;; \
    aarch64) \
        curl -L https://azcopyvnext.azureedge.net/releases/release-${AZCOPY_VERSION}-20240612/azcopy_linux_arm64_${AZCOPY_VERSION}.tar.gz | tar -xvz --strip-components=1 -C "$LOCALBIN" azcopy_linux_arm64_$AZCOPY_VERSION/azcopy; \
        ;; \
esac

