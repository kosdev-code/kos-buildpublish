# Local Development Machine Use Case

This document describes how to use the build/publish tooling on your local machine.  This is useful for setting up the build/publish tooling for the first time for your repository, and also allows for additional debug.

We offer 2 local development paths - In the "developer" use case, your working directory will be mounted into the docker container. In the "automation" use case, your working directory is copied into the docker container and any changes made in the docker image are not persisted on your system.  The "automation" use case assumes that you are building and publishing from the docker container and that there is no need to keep files around after publishing.

# Requirements

  * Docker must installed on your host machine { Docker has been tested on Linux, Windows, and MacOS }
    - On Windows, you must have configured Docker in WSL2 and have a Linux environment in WSL2.  We have tested with Ubuntu on Windows.
    - On Linux, docker must be installed and your user given permission to access the docker daemon.
  * You must use a bash shell on your host platform.
    - 7z must be installed and in your path (for Mac, use Homebrew; for Linux, use apt install p7zip-full)
  * The software source code should be saved to a git repository, and must be producing a KAB or multiple KABs.  The Docker image supports both NPM and Maven builds.
  * You must generate a secrets file that contains your keysets and your artifact store definition(s).  You may also include credentials or other items in your secrets file that is required for building.  Details for setting up your secrets file are available here: https://github.com/kosdev-code/kos-buildpublish/blob/main/documentation/encrypted-secrets-file.md

# Docker Image

This build process uses a Docker image for a reproducible build environment.  Prior to using this tool, you must have the Docker image on your machine.

The docker image for the local "developer" use case can be built by running the "build_docker_for_developer" script in the docker folder.

The docker image for the local "automation" use case can be built by running the "build_docker" script in the docker folder.  Additionally, a docker image is publicly available which can be used.  See https://github.com/kosdev-code/kos-buildpublish/pkgs/container/kos-buildpublish%2Fkos_builder

# Secrets file for Developer Use Case

A script in the secrets/ folder is available, `make_secrets_developer.sh`, which will take your home directory, and will extract the npmrc, maven settings, and default keyset, creating a developer secrets folder.  This developer secrets folder then will be used by default when using the Local developer environment.  The secrets folder for the developer use case may be further customized for your needs.

# Usage

Both the local "developer" use case and local "automation" use case work similarly.  The difference between them is that the local "developer" use case mounts your working folder to $HOME/work, and any files that are modified, created, or deleted in $HOME/work are persisted on your host machine.  The local "automation" use case simply copies all files from your local tree to the docker container.  No files are ever modified on your local host machine.


Before we start, we must have:

  - Docker image
  - Encrypted Secrets file available at secrets/work/<orgname>-secrets.7z
  - Source code repository producing a KAB
  - Source code repository with a configured kosbuild.json file in the root directory of the repository.

First, configure the kosbuild environment:

[Local automation environment]
```
SECRETID=mysecretsdir source kosbuilder.env.source
```
[Local developer environment]
```
# SECRETID is optional - if unspecified and a developer secrets file has been created, it will be used.

SECRETID=mysecretsdir source kosbuilder-developer.env.source
```

The kosbuild environment establishes 2 aliases in your shell environment.  The *kosbuild* alias starts a docker container with the docker image and performs the specified goal.  The *kosbuild_debug* alias starts a docker container witht he docker image, performs the specified goal, and then when done, a shell is run in that environment for you to examine the output.  We expect that *kosbuild_debug* could be useful for resolving some build issues.

There are several arguments you can use to the kosbuild (or kos_build_debug) alias: build, buildpublish, and shell.

Enter a directory containing repository you wish to build.  The second argument is the build configuration.  If the build configuration is not specified, the tooling defaults to kosbuild.json.

To perform a build and exit, simply run:
`kosbuild build [build configuration file]`

To perform a build and publish, simply run:
`kosbuild buildpublish [build configuration file]`

To use the docker image as an environment:
`kosbuild shell [build configuration file]`

