#! /bin/bash

set -e -o pipefail

# this script creates a descriptor.json file that is parseable by kOS which reflects the repo commit id

GITDIRTYSTATUS=$(git diff --no-ext-diff --quiet --exit-code || echo "-dirty")
COMMITID=$(git rev-parse HEAD)

jq --arg gitHash "${COMMITID}${GITDIRTYSTATUS}" -n '{ "kos": { "build": { "gitHash": $gitHash }}}'

