# kOS Studio Build and Publish Process

The optimum workflow for developing kOS applications involves regular artifact builds and publishing. This document describes the tools and process for building your software and publishing your artifacts.  By following this process, enabling automated build and publish with your git repository hosting provider is a short walk.

At a high-level, with this tooling, we can:

  1. Compile code, producing a KAB.
  2. Deploy the KAB to a storage account.
  3. Publish (or register) the KAB on a kOS Studio server.

This process can be run on your local development system or can be deployed into Automation.

## Requirements

  * Docker installed on your host machine { Docker has been tested on Linux, Windows, and MacOS }
    - On Windows, you must have configured Docker in WSL2 and have a Linux environment in WSL2.  We have tested with Ubuntu on Windows.
    - On Linux, docker must be installed and your user given permission to access the docker daemon.
  * You must use a bash shell on your host platform.
    - 7z must be installed and in your path (for Mac, use Homebrew; for Linux, use apt install p7zip-full)
  * Your organization must be set up in kOS Studio Server
  * Any artifact you wish to publish must be configured with kOS Studio Server.
  * For publishing, you must have access to a storage account where you can publish artifacts.  We currently support Azure Blob Storage accounts. 
  * For automation, we currently have templates available for Github.
  * The software source code should be saved to a git repository, and must be producing a KAB or multiple KABs.  The Docker image supports both NPM and Maven builds.

## Secrets
 
 In the context of the kOS build and publishing process, secrets refer to the confidential data or keys required to complete the build process.  These secrets include:
  
  1. Keyset for generating a KAB
  2. Storage account Credentials: for Azure blob store, you must have a container and an associated shared access signature (SAS) token with Create, Add, and Write Permissions.
  3. Studio Server API Key for publishing
  4. [Optional] Maven Settings file (settings.xml normally found in your ~/.m2 folder) - if required for building your code
  5. [Optional] npmrc file that configures repositories and secrets for NPM - if required for building your code

As part of the build and publish process, you must configure a folder containing your secrets.  It follows the following structure

```
   artifactstores/     [Directory containing configuration for Artifact Stores]
   keysets/            [Directory containing keysets used for KAB signing]
   npmrc               [Optional, npmrc file]
   settings.xml        [Optional, maven settings file]
   secrets_password    [Text file containing the password to the Secrets file]
```

This folder is then transformed into an encrypted 7z file with the provided script `make_secrets_file.sh` for use by the build process.  The secrets_password file is not included in the encrypted 7z file, but is used by tooling to create the secrets file and to run the build process locally.

### Keyset

Keyset files are placed in the keysets/ folder.  Each keyset in this folder must be named according to its mode and authority.  For example, the test.demo keyset would be named `test.demo.keyset`.  Multiple keysets can be placed in this directory, each are referenced by name, excluding the .keyset extension.

### Artifact Stores

Artifact store definition files are defined in the artifactstores/ folder.  The naming convention of files in this directory is `<artifactstore name>.json`.  The artifact store name *must* match the name configured in kOS Studio.  Each artifact store definition is a JSON file. The JSON file follows the following schema:

```
Template (comments may not exist in the JSON):
{
    "type": "<type of container>",                              # [REQUIRED] Supported options: { azurecontainer }
    "studio-apikey": "<api key for publishing to Studio>",      # [REQUIRED]
    
    "additional_publish_servers": [                             # [OPTIONAL] add these only if you are publishing to additional servers
        "<publish server1>",                                    #            we will always publish to the public studio server
        "<publish server2>"
    ],

    # The following keys are required when the type is azurecontainer:
    "container": "<URL for azure storage account container>",    # REQUIRED
    "sastoken": "<token with add and create permissions>         # REQUIRED
}

Example: 
{
    "type": "azurecontainer",
    "studio-apikey": "myapikey",
    "container": "https://sause2tcccknaprod0001.blob.core.windows.net/artifacts-kosdemo",
    "sastoken": "sp=r&st=2024-07-03T16:34:33Z&se=2024-07-07T00:34:33Z&spr=https&sv=2022-11-02&sr=c&sig=npz%2FWpuSZ7wFkmuMAHGcUgtEL3CH2i%2FvUxeo0x%2BwIN0%3D",
    "additional_publish_servers": [
        "wss://studiotest.kosdev.com"
    ]
}
```

### Secrets file creation

Use the `make_secrets_file.sh` script in the secrets/ folder of this repo to create an encrypted 7z file with the secrets folder.  The script takes the path to the secrets folder that you have created and an optional output filename.

```
usage: ./make_secrets_file.sh <secrets directory> [secrets-output file]
```

You must have either have a file in the secrets folder called, "secrets_password" or an environment variable, KOSBUILD_SECRETS_PASSWORD, defined when running the make_secrets_file.sh.  This password is applied to the 7z file and is required for decryption.


## Docker Image

This build process uses Docker for a reproducible build environment.  Prior to using this tool, you must have the Docker image on your machine.  To build the Docker image, run the setup_kosbuilder.sh script from this repository.  A docker image is publicly available which can be used.  See https://github.com/kosdev-code/kos-buildpublish/pkgs/container/kos-buildpublish%2Fkos_builder


## Repository Configuration

Your repository must be configured for the kOS Build and publish process.  The kosbuild.json file must be placed in your repository to describe the details of the build and publish process.  An example file is shown below:
```
{
  "default_keyset": "test.demo",
  "build_cmd": "./quickbuild.sh",

  "artifacts": [
    {
      "id": "demo-kos-app",
      "filename": "target/demo-kos-app-${KOS_STD_VERSION_REGEX}.kab",
      "artifactstore": "kosDemos",
      "qualifier": "any",
      "marketplace": 0
    }
  ]
}
```

Each key is described below:

    default_keyset: Defines the keyset that will be used by kabtool when generating KAB files.  The default_keyset value drives how the contents of the ~/kosStudio/tools.properties file to set the keyset.

    build_cmd: Defines the script used to build the code in the repository.

    artifacts: Array which defines the artifacts to deploy to an artifact store and publish.

    artifacts.id: artifact identifier used for publishing to Studio Server

    artifacts.filename: Filename for the KAB once the repository is built.  Note: we support the use of ${KOS_STD_VERSION_REGEX} if your filename has a version number of the typical Maven form, X.Y.Z or X.Y.Z-SNAPSHOT.

    artifacts.artifactstore: name of the artifact store to publish to.  A file in the secrets file, `<artifactstore name>.json` must exist linking your artifact to the artifactstore.

    artifacts.qualifier: [OPTIONAL]- qualifier used for publishing.  This defaults to "any" if not specified.
    
    artifacts.marketplace: [OPTIONAL]- set to 1 for marketplace artifacts.  Defaults to 0.

## Usage
### Build Automation Mode

In Build Automation mode, the automation runs as part of a CI action on an non-development machine.  The encrypted secrets file must be uploaded to a http(s) server accessible to the build automation.  

The tooling expects 2 environment variables to be defined:

  - KOSBUILD_SECRET_PASSWORD is set to the password string for your secrets file
  - KOSBUILD_SECRET_URL is the URL of the encrypted 7z file (http/https)

The URL used should be available to your build runner- a simple `curl` command is used to download the file.

When selecting a password, the password should be a strong password that is not easily cracked by brute force. 

In Github, these environment variables must be defined as repository secrets in your repo under the Settings->Security->Secrets and Variables->Actions.

#### Github Workflow file

Github requires that workflow files be placed in your repository at a location of `.github/workflows`.  We are providing a sample kosbuild.yml file that can be placed which will automate your build.  You will likely want to change the trigger logic - the sample kosbuild.yml file triggers the automation on any push to the main branch.

```
name: kos-build
on:
  push:
    branches:
      - main

jobs:
  kos_build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/kosdev-code/kos-buildpublish/kos_builder:dockerimage
      credentials:
        username: ${{ github.actor }}
        password: ${{ secrets.github_token }}

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4
        with:
            repository: ${{ github.repository }}
            token: ${{ secrets.GITHUB_TOKEN }}
            path: ${{ github.event.repository.name }}
            lfs: true

      - name: Build and Publish
        env:
            KOSBUILD_SECRET_URL: ${{ secrets.KOSBUILD_SECRET_URL }}
            KOSBUILD_SECRET_PASSWORD: ${{ secrets.KOSBUILD_SECRET_PASSWORD }}
        working-directory: ./${{ github.event.repository.name }}
        run: |
            kos_build_handler.sh automation
```

### Developer Mode

In Developer mode, the build and publish process runs on a development machine.  This mode is useful for proving the build and publish process locally prior to deploying to automation.

Before we start, we must have:

  - Docker image
  - Encrypted Secrets file
  - Source code repository producing a KAB
  - Source code repository with a configured kosbuild.json file in the root directory of the repository.

First, configure the kosbuild environment:
```
source kosbuilder_env.source
```

The kosbuild environment establishes 2 aliases in your shell environment.  The *kosbuild* alias starts a docker container with the docker image and performs the specified goal.  The *kosbuild_debug* alias starts a docker container witht he docker image, performs the specified goal, and then allows you to access a shell in that environment.  *kosbuild_debug* is useful for debugging build issues.

Now, enter the repository you wish to build, containing the kosbuild.json file.

To perform a build and exit, simply run:
`kosbuild build`

To perform a build and publish, simply run:
`kosbuild buildpublish`

To use the docker image as an environment:
`kosbuild shell`

In the above cases, kosbuild_debug may also be used- when the goal is done, a shell will remain open for further analysis.

**Important!** The build and publish process in the container is ephemeral. Any files created inside of the environment are removed when the docker container exits.  Files are not modified on your host system when performing the build.

