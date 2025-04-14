#! /bin/bash
THIS_SCRIPT=$(realpath "$0")
THIS_SCRIPT_DIR=$(dirname "$THIS_SCRIPT")

set -e -o pipefail

usage () {
  echo "$0 <encrypted filename>"
  echo "this script will restore the secret detail directory with the contents of the encrypted filename"
  exit 1
}

if [ $# -lt 1 ]; then
  usage  
fi
SECRETDETAIL_ARCHIVE="$1"

cd "${THIS_SCRIPT_DIR}"

7z x -o"${THIS_SCRIPT_DIR}" "${SECRETDETAIL_ARCHIVE}"
