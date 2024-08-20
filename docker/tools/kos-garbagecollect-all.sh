#! /bin/bash

set -e -o pipefail

for ARTSTORE_FILENAME in $HOME/.kosbuild/artifactstores/*.json; do
  artstore="$(basename $ARTSTORE_FILENAME)"
  artstore="${artstore%.*}"

  IS_ENABLED="$(jq -r '.["garbage-collect"]' "${ARTSTORE_FILENAME}")"
  if [ "${IS_ENABLED}" == "true" ]; then
    echo "******************************************************"
    echo $0: Garbage collecting "$artstore"
    # you must specify --delete to this script for it to actually delete the files
    kos-gc-artifactstore.sh "$artstore" "$1"
  fi
done