#! /bin/bash

set -e -o pipefail

# This script is the main entrypoint to performing a kOS build or publish
# Installed to the docker image, this script will be called first when running the docker
# image, and will set up the environment based on the goal.
#
if [ $# -lt 1 ]; then
echo "kos_build_handler: you must specify a goal"
echo "  goal may be one of the following:"
echo "   build [build def]        : this will build the code in the current directory"
echo "                              build def is the filename of the build definition file or"
echo "                              will default to kosbuild.json"
echo "   buildpublish [build def] : this will build and publish the code in the current directory"
echo "   shell                    : this will open a shell inside a temporary container for the kos-build image"
echo
exit 1
fi

BUILD_DEF="$2"

function handleSecrets() {
    load_secrets.sh /mnt/secrets/secrets.7z
}
function copyAppToContainer() {
   echo "kos_build_handler: copying app to the container... please wait."
   mkdir -p ~/work
   cp -r /app/* ~/work
   cd ~/work
   echo "copying done..."
}
function validate_build_definition() {
   # get the build definition
   [ -z "${BUILD_DEF}" ] && BUILD_DEF="kosbuild.json"
   if [ ! -f "${BUILD_DEF}" ]; then
      echo "build definition file ($BUILD_DEF) not found"
      if [ "$1" == "required" ]; then
          echo "error: need build definition"
          exit 1
      fi
   else
      [ "${KOSDEBUG}" == "1" ] && echo "Debug: BUILD definition:" && cat "${BUILD_DEF}" | jq
      # get the default keyset, if specified
      default_keyset=$(jq -r ".default_keyset" "${BUILD_DEF}")
      if [ ! -z "${default_keyset}" ]; then
         # setup the default keyset such that studio tools work with it
         local KEYSET_PATH="$HOME/.kosbuild/keysets/${default_keyset}.keyset"
         [ ! -f "${KEYSET_PATH}" ] && echo "keyset not found in ${KEYSET_PATH}" && exit 1
         mkdir -p "$HOME/kosStudio"
         echo "keyset = ${KEYSET_PATH}" > "${HOME}/kosStudio/tools.properties"
      fi
   fi
}

function handle_build() {
   local BUILD_CMD=$(jq -r ".build_cmd" "${BUILD_DEF}")
   echo "kos_build_handler: building with command: ${BUILD_CMD}"
   "${BUILD_CMD}"
}

function handle_publish() {
   kos_publish.sh "${BUILD_DEF}"
}

function common_handling() {
     cd
     handleSecrets
     copyAppToContainer
}

case $1 in
  build)
     echo "kos_build_handler: build-only"
     common_handling
     validate_build_definition required
     handle_build
     # debug only
     [ "${KOSDEBUG}" == "1" ] && bash
     ;;
  buildpublish)
     echo "kos_build_handler: build and publish"
     common_handling
     validate_build_definition required
     handle_build
     handle_publish
     # debug only
     [ "${KOSDEBUG}" == "1" ] && bash
     ;;
  shell)
     echo "kos_build_handler: shell"
     common_handling
     validate_build_definition notrequired
     bash
     ;;
  *)
     echo "unknown goal $0"
     ;;
esac

