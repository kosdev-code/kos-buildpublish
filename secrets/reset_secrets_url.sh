#!/usr/bin/env bash

# This was created because secrets were being stored in 2 sepereate blob stores
# But that was problematic now they have been changed to a single blob store.

set -e

THIS_SCRIPT=$(realpath "$0")
THIS_SCRIPT_DIR=$(dirname "$THIS_SCRIPT")
SECRET_DETAIL_DIR="${THIS_SCRIPT_DIR}/secret-detail/"
SET_SECRETS_GH="${THIS_SCRIPT_DIR}/set_secrets_github.sh"

SECRET_ORGS=(integration kondra2 kos2_internal pivotbits2 tccc_gep)

for ORG in "${SECRET_ORGS[@]}"; do
  REPOS_FILE="${SECRET_DETAIL_DIR}/log-github-${ORG}.json"
  REPOS_LENGTH=$(jq 'length' "$REPOS_FILE")
  if [ $REPOS_LENGTH -eq 0 ]; then
    continue
  fi
  for i in $(eval echo "{0..$((REPOS_LENGTH - 1))}"); do
    organization=$(jq -r ".[$i].organization" "$REPOS_FILE")
    repository=$(jq -r ".[$i].repository" "$REPOS_FILE")
    prefix=$(jq -r ".[$i].prefix" "$REPOS_FILE")

    if [ "$prefix" = "null" ]; then
      echo "SET_SECRETS_GH $ORG $organization $repository"
      "$SET_SECRETS_GH" "$ORG" "$organization" "$repository"
    else
      echo "SET_SECRETS_GH $organization $repository $prefix"
      "$SET_SECRETS_GH" "$ORG" "$organization" "$repository" "$prefix"
    fi

  done

done
