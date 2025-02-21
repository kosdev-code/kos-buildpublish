#! /bin/bash

# Function to check Azure SAS token expiration
check_sas_token_expiration() {
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

    # we need the SAS token to be valid at least for 1 day
    if [[ $remaining_days -gt 0 ]]; then
      echo "valid"
      return 0
    fi
  fi

  echo "invalid"
}

if [ $# -lt 2 ]; then
   echo "usage: $0 <sas token> <sas token name>"
   echo " script will check wthether the sas token is valid, and will output a message"
   echo " and exit with an error code if the sas token is invalid."
   exit 1
fi

TOKEN="$1"
TOKENNAME="$2"

echo "checking SAS token ${TOKENNAME}..."
STATUS="$(check_sas_token_expiration "${TOKEN}")"
echo "SAS token ${TOKENNAME} is ${STATUS}"
if [ "${STATUS}" == "invalid" ]; then
exit 1
fi
exit 0

