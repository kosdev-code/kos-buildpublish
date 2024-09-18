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
    # remove KOSBUILD_SECRET_PASSWORD export
    export -n KOSBUILD_SECRET_PASSWORD
}
function copyAppToContainer() {
   if [ "${KOSBUILDER_NO_CONTAINER}" == "1" ]; then
      return
   fi
   if [ "${KOSBUILDER_DEV}" == "1" ]; then 
      echo "kos_build_handler: skipping copy to the container due to KOSBUILDER_DEV for user $USER"
      cd ~/work
   else
      echo "kos_build_handler: copying app to the container... please wait."
      mkdir -p ~/work
      cp -a --no-preserve=owner /app/. ~/work
      cd ~/work
      echo "copying done..."
   fi
}
function validate_build_definition() {
   # get the build definition, default to kosbuild.json
   [ -z "${BUILD_DEF}" ] && BUILD_DEF="kosbuild.json"
   if [ ! -f "${BUILD_DEF}" ]; then
      echo "build definition file ($BUILD_DEF) not found"
      if [ "$1" == "required" ]; then
          echo "error: need build definition"
          exit 1
      fi
   else
      export KOSBUILD_BUILD_DEFINITION="$(realpath "${BUILD_DEF}")"
      [ "${KOSDEBUG}" == "1" ] && echo "Debug: BUILD definition:" && cat "${BUILD_DEF}" | jq
      # get the default keyset, if specified
      default_keyset=$(jq -r ".default_keyset" "${BUILD_DEF}")
      if [ "${default_keyset}" != "null" ]; then
         # setup the default keyset such that studio tools work with it
         local KEYSET_PATH="$HOME/.kosbuild/keysets/${default_keyset}.keyset"
         if [ ! -f "${KEYSET_PATH}" ]; then
            DEVELOPER_KEYSET_PATH="$HOME/.kosbuild/keysets/developer.keyset"
            if [ ! -f "${DEVELOPER_KEYSET_PATH}" ]; then
               echo "ERROR: specified keyset ${default_keyset} not found."
               exit 1
            fi
            
            echo "WARNING: ${default_keyset} keyset not found.  Using developer keyset instead."
            KEYSET_PATH="${DEVELOPER_KEYSET_PATH}"
         fi
         mkdir -p "$HOME/kosStudio"
         echo "keyset = ${KEYSET_PATH}" > "${HOME}/kosStudio/tools.properties"
         if [ "${GITHUB_ACTIONS}" == "true" ]; then
            echo "==> kosStudio github actions workaround <=="
            mkdir -p "/root/kosStudio"
            ln -s -f "$HOME/kosStudio/tools.properties" "/root/kosStudio/tools.properties" 
         fi
      else
         echo "WARNING: no default_keyset found in build definition file ${BUILD_DEF}"
      fi
      # hook onload 
      ONLOAD_CMD=$(jq -r ".onload_cmd" "${BUILD_DEF}")
      if [ "${ONLOAD_CMD}" != "null" ]; then
         echo "~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~"
         echo "kos_build_handler: onload with command ${ONLOAD_CMD}"
         ${ONLOAD_CMD}
      fi
   fi
}

function handle_build() {
   kos_build.sh "${BUILD_DEF}"
}

function handle_publish() {
   kos_publish.sh "${BUILD_DEF}"
}

function setup_path() {
   # add $HOME/bin to the path
   mkdir -p "$HOME/bin"
   export PATH="$PATH:$HOME/bin"
}
function common_handling() {
     cd
     handleSecrets
     copyAppToContainer
}

case $1 in
  build)
     echo "~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~"
     echo "kos_build_handler: build-only"
     setup_path
     common_handling
     validate_build_definition required
     handle_build
     # debug only
     if [ "${KOSDEBUG}" == "1" ]; then
        bash
     fi
     ;;
  buildpublish)
     echo "~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~"
     echo "kos_build_handler: build and publish"
     setup_path
     common_handling
     validate_build_definition required
     handle_build
     handle_publish
     # debug only
     if [ "${KOSDEBUG}" == "1" ]; then
        bash
     fi
     ;;
  shell)
     echo "~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~"
     echo "kos_build_handler: shell"
     setup_path
     common_handling
     validate_build_definition notrequired
     bash
     ;;
  automation)
     echo "~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~"
     echo "kosbuild_handler: automation"
     setup_path
     handleSecrets
     export
     validate_build_definition required
     handle_build
     handle_publish
     ;;
  *)
     echo "unknown goal $0"
     ;;
esac

