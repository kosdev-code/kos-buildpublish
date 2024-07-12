#! /bin/bash

THIS_SCRIPT=$(realpath "$0")
THIS_SCRIPT_DIR=$(dirname "$THIS_SCRIPT")

set -e -o pipefail

# build the docker image
pushd ${THIS_SCRIPT_DIR}/docker
./build_docker
popd

