# kOS Studio Build and Publish Process

The optimum workflow for developing kOS applications involves regular artifact builds and publishing. This document describes the tools and process for building your software and publishing your artifacts.  By following this process, enabling automated build and publish with your git repository hosting provider is a short walk.

At a high-level, with this tooling, we can:

  1. Compile code, producing a KAB.
  2. Deploy the KAB to a storage account.
  3. Publish (or register) the KAB on a kOS Studio server.

This process can be run on your local development system or can be deployed into Automation.  This document focuses on the automation use case.  A document is available in the 
documentation folder describing a local development machine use case (https://github.com/kosdev-code/kos-buildpublish/blob/main/documentation/developer-use-case.md).

# Requirements

  * Your organization must be set up in kOS Studio Server
  * Any artifact you wish to publish must be configured with kOS Studio Server.  A repo to hold your artifact must be configured in kOS Studio.
  * For publishing, you must have access to a storage account where you can publish artifacts.  We currently support Azure Blob Storage accounts. 
  * For automation, we currently have templates available for Github Actions.
  * The software source code should be saved to a git repository, and must be producing a KAB or multiple KABs.  The Docker image supports both NPM and Maven builds.
  * You must generate a secrets file that contains your keysets and your artifact store definition(s).  You may also include credentials or other items in your secrets file that is required for building.  Details for setting up your secrets file are available here: https://github.com/kosdev-code/kos-buildpublish/blob/main/documentation/encrypted-secrets-file.md


# Build Configuration File

Your repository must be configured for the kOS Build and Publish process.  A build configuration file (default name: kosbuild.json) file must be placed in your repository to describe the details of the build and publish process. We recommend placing it in the .github folder subdirectory off the root of your repository.  An example file is shown below:

```
{
  "default_keyset": "test.demo",
  "prebuild_cmd": "./prebuild.sh"
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

    default_keyset: Defines the keyset that will be used by kabtool when generating KAB files.  The default_keyset value drives the contents of the ~/kosStudio/tools.properties file to set the keyset.

    onload_cmd: [OPTIONAL] When executing the kos_build_handler, after the secrets have been loaded, this onload_cmd is run automatically.  You may use this to initialize your environment or add additional set-up if necessary.

    prebuild_cmd: [OPTIONAL]  When the build goal is taken, this is called before the *build_cmd*.  No action is taken if this is not set.

    build_cmd: When the build goal is taken, this defines the command used to build the code in the repository.
    
    postbuild_cmd: [OPTIONAL] When the build goal is taken, this defines the command used after a successful execution of the build_cmd.

    prepublish_cmd: [OPTIONAL] When the publish goal is taken, this defines the command executed before publishing artifacts defined in this file.

    postpublish_cmd: [OPTIONAL] When the publish goal is taken, this defines the command executed after publishing artifacts defined in this file.

    artifact_fail_policy: [OPTIONAL, default: hard] When set to soft, the build automation will continue if the artifact file does not exist.  If set to hard, the automation will fail if the artifact to be published does not exist.

    artifacts: Array which defines the artifacts to deploy to an artifact store and publish.

    artifacts.id: artifact identifier used for publishing to Studio Server

    artifacts.filename: Filename for the KAB once the repository is built.  Note: we support the use of ${KOS_STD_VERSION_REGEX} if your filename has a version number of the typical Maven form, X.Y.Z or X.Y.Z-SNAPSHOT.

    artifacts.artifactstore: name of the artifact store to publish to.  A file in the secrets file, `<artifactstore name>.json` must exist linking your artifact to the artifactstore.

    artifacts.qualifier: [OPTIONAL]- qualifier used for publishing.  This defaults to "any" if not specified.
    
    artifacts.marketplace: [OPTIONAL]- set to 1 for marketplace artifacts.  Defaults to 0.

You are welcome to extend this file as you see fit.  Please prefix any additional fields you add with 'extra_' to maintain forwards compatibility.

# Secrets File

You must configure your encrypted secrets file for automation.  See details at https://github.com/kosdev-code/kos-buildpublish/blob/main/documentation/encrypted-secrets-file.md.

# Usage

Automation runs as part of a CI action on a machine, typically controlled by your GIT hosting vendor.  The automation will need access to the encrypted secrets file.  The encrypted secrets file must be uploaded to a http(s) server which is accessible to the build automation.  

The tooling expects 2 environment variables to be defined:

  - KOSBUILD_SECRET_PASSWORD is set to the password string for your secrets file
  - KOSBUILD_SECRET_URL is the URL of the encrypted 7z file (http/https)

The URL used should be available to your build runner- a simple `curl` command is used to download the file.

When selecting a password, the password should be a strong password that is not easily cracked by brute force. 

In Github, these environment variables must be defined as repository secrets in your repo under the Settings->Security->Secrets and Variables->Actions.

## Github Workflow file

Github requires that workflow files be placed in your repository at a location of `.github/workflows`.  We are providing a sample kosbuild.yml file that can be placed which will automate your build.  You may want to change the trigger logic - the sample kosbuild.yml file triggers the automation on any push to the main branch.  A sample Github workflow file can be found in the automation-template folder.

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
            kos_build_handler.sh automation   # optional: [ build configuration file ]
```

# Walkthrough
Assume that you have an NPM or Java repository on your developer machine that will build a kab by running a simple script.  We will also assume that the repository is hosted on Github.  We will walk you through the process of automating the build and publish process.

1. Setup an Azure storage account if you don't already have one.  You should create a container to hold your artifacts which has "Blob" access (meaning the artifacts can be downloaded publicly).
   - Once created, go to the Container in the Azure Portal, Go to Settings->Shared Access Tokens, and create a SAS token with Add, Create, Write permissions with a expiry window that meets your security requirements.  Capture the SAS Token.

2. In kOS Studio, click the Gear icon and select "Setup Artifact Stores".

   A. Click Create Store in the upper right corner

   B. The name should reflect your artifact store name- this is also known as the REPO name.  We will use the value `repo-myorg` for this example.  

   C. Set the URL to the base URL of where your artifacts will go.  This should reflect the URL of your container you setup for your Azure account- we will use `https://myartifactstore.blob.core.windows.net/artifacts` for this example.

3. In kOS Studio, click the Gear icon and Select "Create API Keys".

   A. Click Create API Key in the upper right corner.

   B. Name the API Key something meaningful, e.g. organization publish key

   C. Capture the API key that it presents to you.  We will assume it is `fb662410-5b49-4e8b-8274-5c531b34236f` for this example.

4. In kOS Studio, click the Gear icon and Select "Artifact Management".
   
   A. Click Create new Artifact in the upper right corner.

   B. Name your artifact and fill in the remaining fields.  Capture the name of this artifact.  We will assume that it is called `my-application-artifact`

4. Set-up your secrets file.

   A. Clone this repository, and then go to the secrets directory:
      ```
      $ cd secrets
      ```
   B. Create a directory template for your secrets:
      ```
        # replace organization name and password with actual values
        # Use a strong password for the password in this case!  You are responsible for your own security.
      $ ./make_secrets_dir_template.sh <organization name> <password>
      ```
      A directory called `<organization name>` is created.  Go to this directory:
      ```
      $ cd <organization name>
      ```
   C. Configure your artifact store file.  A template was created in the previous step.  
      - Rename the template.json file in the artifactstore directory to match the repo name you configured in kOS Studio.
      ```
        mv artifactstores/template.json repo-myorg.json
      ```
      - Edit the repo-myorg.json file.  
      - studio-apikey must be set to the the API key you created in the previous steps.
      - container must be set to the URL of your azure container
      - sastoken should be set to the token you generated in the previous steps.

      Example:
      ```
      {
        "type": "azurecontainer",
        "studio-apikey": "fb662410-5b49-4e8b-8274-5c531b34236f",
        "container": "https://myartifactstore.blob.core.windows.net/artifacts",
        "sastoken": "sp=acw&st=2024-07-03T16:34:33Z&se=2024-07-07T00:34:33Z&spr=https&sv=2022-11-02&sr=c&sig=npz%2FWpuSZ7wFkmuMAHGcUgtEL3CH2i%2FvUxeo0x%2BwIN0%3D"
      }
      ```

   D. Place your keysets in the keysets/ folder.  Keysets must begin with 'test.' or 'prod.' and have a file extension of '.keyset'.  For example, `test.myorg.keyset`

      TODO: document how you get your keyset

   E. If your build environment needs your `npmrc` file, then place this in the secrets directory:
      ```
      cp ~/.npmrc npmrc
      ```
      Important: verify that your `npmrc` file has exactly the information you wish for the build runner to have in it.  You are responsible for your own security.

   F. If your build environment needs your Maven Settings file, then place this in the secrets directory:
      ```
      cp ~/.m2/settings.xml settings.xml
      ```
      Important: verify that your `settings.xml` file has exactly the information you wish for the build runner to have in it.  You are responsible for your own security.

   G. Create the encrypted secrets file:
      ```
      # first go back to the secrets directory
      cd secrets
      ./make_secrets_file.sh <organization name>
      ```
      After this step, a file will be placed in your secrets_mount folder called secrets_mount/'<organization name>-secrets 7z'.  This is your encrypted 7z file.

5. Upload your encrypted 7z file to a location that is accessible by the Github Runners.  It should have a URL where it can be accessed.

6. In your Github repository, go to Settings and create 2 secrets:

   KOSBUILD_SECRET_URL must be set to the URL where the encrypted 7z file may be accessed

   KOSBUILD_SECRET_PASSWORD must be set to the password for your encrypted 7z file.

7. In your Github repository, create a kosbuild.json file which drives the build process.  Place it in the .github folder.  Example:

  ```
  {
    "default_keyset": "test.myorg",
    "build_cmd": "./build.sh",

    "artifacts": [
      {
        "id": "my-application-artifact",
        "filename": "output/application.kab",
        "artifactstore": "repo-myorg"
      }
    ]
  }
  ```
  
  In this example, the default_keyset matches to a keyset file 'test.myorg.keyset' in the keysets directory contained in the secrets archive.

  The repository contains a script called build.sh (with executable permissions) and in the root repository directory that builds the code.

  The artifact is defined and the artifactstore value matches to a file 'repo-myorg.json' contained in the secrets archive.

8. Finally, create a workflow file in your repository called `.github/workflows/kosbuild.yml` (or similar) that triggers the build on pushes to the main branch.

```
name: kos-build
on:
  push:
    branches:
      - main
  workflow_dispatch:

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
            kos_build_handler.sh automation .github/kosbuild.json
```

9. When you push to the main branch of your repository, automation will automatically start to build and publish your artifacts.

###
TODO

Document deployment of extra resources using kos_deploy_to_artifactstore

Normalize market artifact stores and market option on artifact.  (remove from individual artifact store)