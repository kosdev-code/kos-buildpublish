#! /bin/bash
THIS_SCRIPT=$(realpath "$0")
THIS_SCRIPT_DIR=$(dirname "$THIS_SCRIPT")

set -e -o pipefail

echo "this script will backup the secret detail directory, saving"
echo "the passwords to the secret archives, the azure token, and the logs"
echo "from configuring the repositories with GitHub"

cd "${THIS_SCRIPT_DIR}"

FILENAME="${THIS_SCRIPT_DIR}/secret_detail_backup-$(date '+%Y%d%m%H%M').7z"

# we are not backing up the GitHub Token since that should be set by
# the user
FILES_TO_BACKUP="secret-detail/secrets-*.json secret-detail/log-github-* secret-detail/azure-token*.json"

7z a -t7z -mhe -p "${FILENAME}" ${FILES_TO_BACKUP}

echo "Secret-details backed up to ${FILENAME}"
