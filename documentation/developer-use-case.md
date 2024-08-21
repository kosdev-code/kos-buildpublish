# Local Development Machine Use Case

This document describes how to use the build/publish tooling on your local machine.  For building artifacts in a production environment, we recommend the automation use case.  However, this mode is useful when building locally or when additional debug is needed.

WORK-IN-PROGRESS

# Requirements

  * Docker must installed on your host machine { Docker has been tested on Linux, Windows, and MacOS }
    - On Windows, you must have configured Docker in WSL2 and have a Linux environment in WSL2.  We have tested with Ubuntu on Windows.
    - On Linux, docker must be installed and your user given permission to access the docker daemon.
  * You must use a bash shell on your host platform.
    - 7z must be installed and in your path (for Mac, use Homebrew; for Linux, use apt install p7zip-full)
  * The software source code should be saved to a git repository, and must be producing a KAB or multiple KABs.  The Docker image supports both NPM and Maven builds.
  * You must generate a secrets file that contains your keysets and your artifact store definition(s).  You may also include credentials or other items in your secrets file that is required for building.  Details for setting up your secrets file are available here: https://github.com/kosdev-code/kos-buildpublish/blob/main/documentation/encrypted-secrets-file.md

# Docker Image

This build process uses a Docker image for a reproducible build environment.  Prior to using this tool, you must have the Docker image on your machine.  To build the Docker image, run the setup_kosbuilder.sh script from this repository.  A docker image is publicly available which can be used.  See https://github.com/kosdev-code/kos-buildpublish/pkgs/container/kos-buildpublish%2Fkos_builder

# Build Configuration File

The same build configuration file from the automation use case applies to the developer use case.  However, it is expected that you might not publish artifacts in the developer use case.

# Developer Mode

In Developer mode, the build and publish process runs on a development machine.  This mode is useful for proving the build and publish process locally prior to deploying to automation.

Before we start, we must have:

  - Docker image
  - Encrypted Secrets file available at secrets/secrets_mount/<mysecretsdir>-secrets.7z
  - Source code repository producing a KAB
  - Source code repository with a configured kosbuild.json file in the root directory of the repository.

First, configure the kosbuild environment:
```
SECRETID=mysecretsdir source kosbuilder-with-secrets.source
```


The kosbuild environment establishes 2 aliases in your shell environment.  The *kosbuild* alias starts a docker container with the docker image and performs the specified goal.  The *kosbuild_debug* alias starts a docker container witht he docker image, performs the specified goal, and then allows you to access a shell in that environment.  *kosbuild_debug* is useful for debugging build issues.

Now, enter the repository you wish to build (which contains the build configuration file) file.  If the build configuration is not specified, the tooling defaults to kosbuild.json.

To perform a build and exit, simply run:
`kosbuild build [build configuration file]`

To perform a build and publish, simply run:
`kosbuild buildpublish [build configuration file]`

To use the docker image as an environment:
`kosbuild shell [build configuration file]`

In the above cases, kosbuild_debug may also be used- when the goal is done, a shell will remain open for further analysis.

**Important!** The build and publish process in the container is ephemeral. Any files created inside of the environment are removed when the docker container exits.  Files are not modified on your host system when performing the build.
