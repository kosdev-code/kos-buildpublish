#! /bin/bash
THIS_SCRIPT=$(realpath "$0")
THIS_SCRIPT_DIR=$(dirname "$THIS_SCRIPT")

set -e -o pipefail

stoponerror=1

error() {
  local msg="$1"
  echo "ERROR: $msg"
  if [ "$stoponerror" -eq 1 ]; then
    exit 1
  fi  
}

get_sas_token_expiredays() {
  local sas_token="$1"

  # Extract the 'se' (signed expiry) parameter from the SAS token
  local expiry_time=$(echo "$sas_token" | grep -oE "se=[^&]+" | cut -d'=' -f2)

  if [[ -z "$expiry_time" ]]; then
    echo "Error: Could not find 'se' (signed expiry) parameter in SAS token."
    return 1
  fi

  # Decode the URL-encoded expiry time
  local decoded_expiry_time=$(echo "$expiry_time" | sed 's/%[0-9A-Fa-f][0-9A-Fa-f]/\\x&/g')

  # Convert the ISO 8601 expiry time to Unix timestamp
  local expiry_timestamp=$(date -d "$decoded_expiry_time" +%s)

  if [[ -z "$expiry_timestamp" || "$expiry_timestamp" -eq 0 ]]; then
      echo "Error: Invalid or unparsable expiry time: $decoded_expiry_time"
      return 1
  fi

  # Get the current Unix timestamp
  local current_timestamp=$(date +%s)

  # Compare timestamps
  if [[ "$expiry_timestamp" -gt "$current_timestamp" ]]; then
    local remaining_seconds=$((expiry_timestamp - current_timestamp))
    local remaining_minutes=$((remaining_seconds / 60))
    local remaining_hours=$((remaining_minutes / 60))
    local remaining_days=$((remaining_hours / 24))

    echo "${remaining_days}"
    return 0
  fi

  echo "0"
  return 0
}

function check_artifactstore_dir () {
    local asdir
    local repo

    asdir="$1"
    for repo in "${asdir}/"*.json; do
       if [ -f "${repo}" ]; then
           sastoken="$(jq -r .sastoken ${repo})"
           if [ $? -ne 0 ]; then
              continue
           fi

           DAYSLEFT=$(get_sas_token_expiredays "${sastoken}")
           if [ $? -eq 0 ]; then
            echo "${DAYSLEFT} days left in $(basename ${repo})"

            if [ "$DAYSLEFT" == "0" ]; then
               error "SAS token expired"
            fi
           fi

         sastoken="$(jq -r '.["gc-sastoken"]' ${repo})"
         if [ "${sastoken}" == "null" ]; then
            continue
         fi
         DAYSLEFT=$(get_sas_token_expiredays "${sastoken}")
         echo "${DAYSLEFT} days left in $(basename ${repo}) [GC Token]"
         if [ "$DAYSLEFT" == "0" ]; then
               error "SAS token expired"
          fi
       fi
    done
}

check_json_validity() {
  local file="$1"
  jq '.' < "$file" &> /dev/null
  local result=$?
  if [ "$result" -eq 0 ]; then
    return 0
  else
    return 1
  fi
}

check_json_files() {
  local path="$1"
  
  for file in "$path"/*.json; do
    if ! $(check_json_validity "$file"); then
      error "invalid JSON file: $file"
      return 1
    fi
  done
}

function check_secrets_dir () {
    local secretsdir
    local artifactstoredir

    secretsdir="$1"
    artifactstoredir="${secretsdir}/artifactstores"
    if [ -d "${artifactstoredir}" ]; then
       check_artifactstore_dir "${artifactstoredir}" || error "invalid artifact store ${artifactstoredir}"
       check_json_files "${artifactstoredir}" || error "invalid json files found in ${artifactstoredir}"
    fi
}

declare -a EXCLUDED_DIRS="(secrets_mount developer)"
function isExcluded() {
    local dir="$1"
    for excluded_dir in "${EXCLUDED_DIRS[@]}"; do
      if [[ "$dir" == "$excluded_dir" ]]; then
        return 0 # True (excluded)
      fi
    done
    return 1 # False (not excluded)
}


for dir in *; do
  if [ -d "${dir}" ]; then
    # Check if the directory is excluded
    if ! isExcluded "$dir"; then
      check_secrets_dir "${THIS_SCRIPT_DIR}/${dir}"
    fi
  fi
done
