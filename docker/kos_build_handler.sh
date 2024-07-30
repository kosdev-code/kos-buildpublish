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
echo "   automation               : this will run the automation goal, which includes build and publish"
echo
exit 1
fi

BUILD_DEF="$2"

function handleSecrets() {
    if [ "${KOSBUILD_NO_SECRETS}" == "1" ]; then
      echo "KOSBUILD_NO_SECRETS defined - secrets handling is bypassed"
      return
    fi
    if [ -z "${KOSBUILD_SECRET_PASSWORD}" ]; then
      echo "ERROR: KOSBUILD_SECRET_PASSWORD not defined"
      exit 1
    fi

    LOCAL_SECRETS_FILE=/mnt/secrets/secrets.7z
    if [ -f "${LOCAL_SECRETS_FILE}" ]; then
       load_secrets.sh "${LOCAL_SECRETS_FILE}"
    else
       if [ ! -z "${KOSBUILD_SECRET_URL}" ]; then
         DL_SECRETS_FILE="/tmp/secrets.7z"
         echo "downloading secrets file from ${KOSBUILD_SECRET_URL}"
         curl -f -o "${DL_SECRETS_FILE}" "${KOSBUILD_SECRET_URL}"
         load_secrets.sh "${DL_SECRETS_FILE}"
       else
         echo "ERROR: No secrets file available.  Define KOSBUILD_SECRET_URL and KOSBUILD_SECRET_PASSWORD or include secrets file at ${LOCAL_SECRETS_FILE}"
         exit 1
       fi
    fi
    
}
function copyAppToContainer() {
   echo "kos_build_handler: copying app to the container... please wait."
   mkdir -p ~/work
   cp -a /app/. ~/work
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
         if [ "${GITHUB_ACTIONS}" == "true" ]; then
            echo "==> kosStudio github actions workaround <=="
            mkdir -p "/root/kosStudio"
            ln -s -f "$HOME/kosStudio/tools.properties" "/root/kosStudio/tools.properties" 
         fi
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
  automation)
     echo "kosbuild_handler: automation"
     export
     handleSecrets
     validate_build_definition required
     handle_build
     handle_publish
     ;;
  *)
     echo "unknown goal $0"
     ;;
esac

