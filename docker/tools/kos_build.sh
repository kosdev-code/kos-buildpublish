#! /bin/bash
set -e -o pipefail

# This script handles the kos build process, given a kosbuild json file.
# Inputs: 
#   - <build definition json file> drives the publish process

function usage() {
    echo "usage: $0 <kos build configuration json file>"
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

CFGFILE=$1

if [ ! -f "${CFGFILE}" ]; then
  usage
  exit 1
fi


function handle_build() {
   local BUILD_DEF="$1"
   local PREBUILD_CMD
   local POSTBUILD_CMD
   local BUILD_CMD

   export BUILD_DEFINITION="${BUILD_DEF}"

   PREBUILD_CMD=$(jq -r ".prebuild_cmd" "${BUILD_DEF}")
   if [ "${PREBUILD_CMD}" != "null" ]; then
     echo "kos_build_handler: prebuild with command ${PREBUILD_CMD}"
     ${PREBUILD_CMD}
   fi

   BUILD_CMD=$(jq -r ".build_cmd" "${BUILD_DEF}")
   if [ "${BUILD_CMD}" == "null" ]; then
     echo "error: no build_cmd found in build definition, ${BUILD_DEF}"
     exit 1
   fi
   echo "kos_build_handler: building with command: ${BUILD_CMD}"
   ${BUILD_CMD}

   POSTBUILD_CMD=$(jq -r ".postbuild_cmd" "${BUILD_DEF}")
   if [ "${POSTBUILD_CMD}" != "null" ]; then
     echo "kos_build_handler: postbuild with command ${POSTBUILD_CMD}"
     ${POSTBUILD_CMD}
   fi
}


###  SHELL SCRIPT starts here:
handle_build "${CFGFILE}"
