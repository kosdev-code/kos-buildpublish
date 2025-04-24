#! /bin/bash
THIS_SCRIPT=$(realpath "$0")
THIS_SCRIPT_DIR=$(dirname "$THIS_SCRIPT")

set -e -o pipefail

# This script will walk every artifact store and find the sas tokens, replacing them
# with new versions that expire in 90 days.  This applies only to azurecontainer artifactstore types.
# Your artifactstore must have an existing token in it with permissions in order to process it.

# Requirements
# we assume that you have already logged into azure using az login


function replace_sas_in_json_file() {
  local JSONFILE="$1"
  local FIELD="$2"

  SASTOKEN="$(jq -r '.["'${FIELD}'"]' "${JSONFILE}")"

  if [ "$SASTOKEN" != "null" ]; then 
        PERMISSIONS="$(echo "$SASTOKEN" | grep -oP 'sp=\K[^&]*')"
        EXPIRY="$(date -u -d "$(date +%Y-%m-%d) + 90 days" +%Y-%m-%dT%H:%M:%SZ)"
        echo "${ACCOUNT}, ${CONTAINERNAME}, $PERMISSIONS, $SASTOKEN, "

        echo "request sas for ${FIELD} on container $CONTAINERNAME, permissions ${PERMISSIONS}"
           SASTOKEN="$(az storage container generate-sas \
              --account-name "${ACCOUNT}" \
              --name "${CONTAINERNAME}" \
              --permissions ${PERMISSIONS} \
              --expiry "${EXPIRY}" \
              --start "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
              --https-only)"
          SASTOKEN="${SASTOKEN#\"}"
          SASTOKEN="${SASTOKEN%\"}"
          SASTOKEN="$(echo $SASTOKEN | sed 's/%3A/:/g')"

         jq  --arg FIELD $FIELD --arg SASTOKEN "$SASTOKEN" '.[$FIELD] = $SASTOKEN' "${JSONFILE}"  > tmp.json && mv tmp.json "${JSONFILE}"
      fi
}

function replace_sas_tokens_artifactstore() {
    local JSONFILE="$1"

    TYPE="$(jq -r .type "${JSONFILE}")"

    if [ "$TYPE" == "azurecontainer" ]; then
      CONTAINER="$(jq -r .container "${JSONFILE}")"
      host=$(echo "$CONTAINER" | sed 's#^https://##g' | cut -d'/' -f1)
      # Extract the first word before the first dot
      ACCOUNT=$(echo "$host" | cut -d'.' -f1)
      CONTAINERNAME=$(echo "$CONTAINER" | cut -d'/' -f4)
      replace_sas_in_json_file "${JSONFILE}" "sastoken"
      replace_sas_in_json_file "${JSONFILE}" "gc-sastoken"
    fi
}

function iterate_on_artifactstores() {
  shopt -s globstar

   for json_file in work/*/artifactstores/*.json; do        
      if [[ -f "$json_file" ]]; then
      # Print the name of the file being processed.
      echo "Processing file: $json_file"
      replace_sas_tokens_artifactstore $json_file
      fi
    done

  shopt -u globstar
}


cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/sm_funcs.source"
echo "this tool will iterate on your artifactstores and replace the sastoken and garbage collection token with a new one good for 90 days"
echo "we assume you have already logged into your azure account using az login"
confirm "continue?"

iterate_on_artifactstores


