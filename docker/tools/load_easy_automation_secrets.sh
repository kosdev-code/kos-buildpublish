#! /bin/bash
# This script is used to load secrets for easy automation builds.
# It fetches the secrets from the KOS Studio server using the studio api key for
# authentication.
# This script depends on the STUDIO_APIKEY environment variable being set in the build automation.
# BUILD_DEF is to be passed in as the first argument, which is the build definition file.
#
#It will create the following files and directories in the user's home directory:
# - $HOME/.npmrc: NPM configuration file with GitHub _authToken
# - $HOME/.kosbuild/keysets/: Directory for keysets    A keyset will be placed here based on the default_keyset specified in the build definition
# - $HOME/.kosbuild/artifactstores/: Directory for artifact stores
# - $HOME/.kosbuild/artifactstores/<artifactstore>.json: JSON file with artifact store configuration

DEFAULT_STUDIO_SERVER="https://studio.kosdev.com"
LOCAL_TEST_SERVER="host.docker.internal:8080"
SERVER=${DEFAULT_STUDIO_SERVER}

BUILD_DEF=$1

#setup npmrc
touch $HOME/.npmrc
echo "//npm.pkg.github.com/:_authToken=${GITHUB_AUTH_TOKEN}
@kosdev-code:registry=https://npm.pkg.github.com/" >>$HOME/.npmrc

#Get keyset from server used to sign the artifacts
# Set default build definition file
[ -z "${BUILD_DEF}" ] && BUILD_DEF=".github/kosbuild.json"

# Check if build definition file exists
if [ ! -f "${BUILD_DEF}" ]; then
  echo "build definition file ($BUILD_DEF) not found, in easy automation mode"
  exit 1
else
  # Get the default keyset, if specified
  default_keyset=$(jq -r ".default_keyset" "${BUILD_DEF}")

  # Create keysets directory if it doesn't exist
  mkdir -p "$HOME/.kosbuild/keysets/"

  # Check if default_keyset starts with "test."
  if [[ "${default_keyset}" == test.* ]]; then
    echo "Processing test keyset..."
    # Get base64 encoded keyset via curl request
    response=$(curl -s "${SERVER}/api/buildAutomation/keyset/test?apiKey=${STUDIO_APIKEY}")

    # Extract the base64 data from JSON response and decode it
    echo "${response}" | jq -r ".data" | base64 -d >"$HOME/.kosbuild/keysets/${default_keyset}.keyset"

    if [[ $? -eq 0 && -f "$HOME/.kosbuild/keysets/${default_keyset}.keyset" ]]; then
      echo "Test keyset saved successfully"
    else
      echo "ERROR: Failed to process test keyset"
      exit 1
    fi

  # Check if default_keyset starts with "prod."
  elif [[ "${default_keyset}" == prod.* ]]; then
    echo "Processing prod keyset..."

    # Check for KOSBUILD_SECRET_PASSWORD
    if [ -z "${KOSBUILD_SECRET_PASSWORD}" ]; then
      echo "ERROR: KOSBUILD_SECRET_PASSWORD not defined"
      exit 1
    fi

    # Get the production keyset URL
    PROD_URL="${SERVER}/api/buildAutomation/keyset/prod/url?apiKey=${STUDIO_APIKEY}"

    # Perform curl request to get encrypted zip file link
    zip_link=$(curl -s "${PROD_URL}" | jq -r ".data")

    if [ -z "${zip_link}" ] || [ "${zip_link}" == "null" ]; then
      echo "ERROR: Failed to get download link"
      exit 1
    fi

    # Download the encrypted zip file
    temp_zip="/tmp/prod_keyset.zip"
    curl "${zip_link}" -o "${temp_zip}"

    # Extract with 7zip using the secret password
    7z x "${temp_zip}" -p"${KOSBUILD_SECRET_PASSWORD}" -o"$HOME/.kosbuild/keysets/"

    mv "$HOME/.kosbuild/keysets/"* "$HOME/.kosbuild/keysets/${default_keyset}.keyset" 2>/dev/null || true

    # Clean up temporary zip file
    rm -f "${temp_zip}"

  else
    echo "Unknown keyset type: ${default_keyset}, must start with 'test.' or 'prod.'"
    exit 1
  fi
fi

# Get the artifact store container and SAS token from the server
RES=$(curl -s "${SERVER}/api/buildAutomation/containerAndSASToken?apiKey=${STUDIO_APIKEY}")

if [ $? -ne 0 ] || [ -z "$RES" ]; then
  echo "ERROR: Failed to get response from server"
  exit 1
fi

ARTSTORE_CONTAINER=$(echo "${RES}" | jq -r ".data.container")
ARTSTORE_SASTOKEN=$(echo "${RES}" | jq -r ".data.SAS")

if [ "$ARTSTORE_CONTAINER" == "null" ] || [ "$ARTSTORE_SASTOKEN" == "null" ]; then
  echo "ERROR: Failed to parse container or SAS token from response"
  echo "Response was: ${RES}"
  exit 1
fi

REPO="default_artifact_store"

# Create the artifact store configuration file to work with current tools
mkdir -p $HOME/.kosbuild/artifactstores
cat >$HOME/.kosbuild/artifactstores/${REPO}.json <<EOF
{
  "type": "azurecontainer",
  "studio-apikey": "${STUDIO_APIKEY}",
  "container": "${ARTSTORE_CONTAINER}",
  "sastoken": "${ARTSTORE_SASTOKEN}"
}
EOF
