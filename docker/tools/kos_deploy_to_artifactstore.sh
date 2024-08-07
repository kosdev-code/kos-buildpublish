#! /bin/bash

if [ $# -lt 1 ]; then
echo "usage $0 <CFG JSON FILE>"
echo "  will deploy files based on the json configuration file to an artifact-store"
exit 1
fi

set -e -o pipefail

CFG_JSON="$1"

# get the length
DEPLOY_COUNT=$(cat "${CFG_JSON}" | jq '. | length')
if [ $DEPLOY_COUNT -eq 0 ]; then
  echo "no files to deploy."
  exit 0
fi

# now iterate through each of the items in the json
for i in $( eval echo {0..$((DEPLOY_COUNT-1))} ); do
   deploy_input=$(jq -r ".[$i].input_file" "${CFG_JSON}")
   deploy_output=$(jq -r ".[$i].output_file" "${CFG_JSON}")
   deploy_artstore=$(jq -r ".[$i].artstore" "${CFG_JSON}")
   
   [ "{deploy_input}" == "null" ] && "echo error: deploy_input is null" && exit 1
   [ "{deploy_output}" == "null" ] && "echo error: deploy_output is null" && exit 1
   [ "{deploy_artstore}" == "null" ] && "echo error: deploy_artstore is null" && exit 1
   
   kos_upload_artifact "${deploy_input}" "${deploy_artstore}" "${deploy_output}"
done
