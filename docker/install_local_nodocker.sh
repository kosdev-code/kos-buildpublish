#! /bin/bash

THIS_SCRIPT=$(realpath "$0")
THIS_SCRIPT_DIR=$(dirname "$THIS_SCRIPT")

set -e

echo "install kos_buildpublish for non-docker use case"
echo "  this script assumes that you already have the dependencies needed on your system"

LOCALBIN="$HOME/.kosbuild/bin"
mkdir -p "${LOCALBIN}"

cp -r "${THIS_SCRIPT_DIR}/tools/." "${LOCALBIN}"
cp "${THIS_SCRIPT_DIR}/kos_build_handler.sh" "${LOCALBIN}"
chmod +x "${LOCALBIN}/load_secrets.sh" "${LOCALBIN}/kos_"* "${LOCALBIN}/kabtool" "${LOCALBIN}/publishtool"

sed -i 's|/usr/local/lib|'"${LOCALBIN}"'|g' "${LOCALBIN}/kabtool"
sed -i 's|/usr/local/lib|'"${LOCALBIN}"'|g' "${LOCALBIN}/publishtool"

OS_TYPE="$(uname -o)"
echo "uname returns: ${OS_TYPE}"


# need to install azcopy
if [ "${OS_TYPE}" == "Msys" ]; then
    AZCOPY_URL="https://aka.ms/downloadazcopy-v10-windows"

    echo "Download azcopy for Windows..."
    TMP_AZCOPY_ZIP="azcopy_tmp.zip"
    curl -f -L -o "${TMP_AZCOPY_ZIP}" "${AZCOPY_URL}"
    unzip -j "${TMP_AZCOPY_ZIP}" "*/azcopy*" -d "$LOCALBIN"
    rm "${TMP_AZCOPY_ZIP}"
else
    case $(uname -m) in \
        x86_64) \
        AZCOPY_URL=https://aka.ms/downloadazcopy-v10-linux
            ;; \
        aarch64) \
        AZCOPY_URL=https://aka.ms/downloadazcopy-v10-linux-arm64
            ;; \
        arm64) \
        AZCOPY_URL=https://aka.ms/downloadazcopy-v10-linux-arm64
            ;; \
    esac
    if [ -z "${AZCOPY_URL}" ]; then
    echo "error: no azcopy url"
    exit 1
    fi

    TMP_AZCOPY_TARBALL=azcopy_tmp.tar.gz
    curl -f -L -o "${TMP_AZCOPY_TARBALL}" "${AZCOPY_URL}"
    extracted_dir=$(tar -tf ${TMP_AZCOPY_TARBALL} | head -1 | cut -d/ -f1)
    tar xzf "${TMP_AZCOPY_TARBALL}" --strip-components=1 --directory "$LOCALBIN" "${extracted_dir}/azcopy"
    rm "${TMP_AZCOPY_TARBALL}"
fi

# get the kos tools
"${THIS_SCRIPT_DIR}/kos_gettools"
cp "${THIS_SCRIPT_DIR}/lib/kabtool.jar" "${THIS_SCRIPT_DIR}/lib/publishtool.jar" "${LOCALBIN}"

