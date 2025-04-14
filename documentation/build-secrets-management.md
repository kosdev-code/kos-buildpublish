# Build Secrets Management

This document describes how to manage build secrets with the kos build automation tooling.

## References

The git repository available [here](https://github.com/kosdev-code/kos-buildpublish) contains the Docker image creation details, the automation details, kOS build process and publishing details, and secrets management.  This is a public repository available to anyone on the internet, and it does NOT contain secrets.

## Secrets

Build Secrets consist of privileged information associated with building and publishing code artifacts.  Generally, each organization will have their own build secrets consisting of keysets, artifact stores, credentials, and other details which are specific to build/publishing for their organization and code repositories.  

## Operational Details

Documentation is available in the readmes and documentation in the referenced git repository.  However, in this document, we will walk through several typical use cases.

### Creating a new secrets file for an Organization
Let's say a new organization needs to configure build secrets for their kOS automation.  They have keysets *test.acme* and *prod.acme*. They have an artifact store defined in kOS Studio called *acmeRepo* which will store market artifacts.  They also need to provide npm and maven credentials for building their repository.

First, you would clone the git repository referenced above.  

Next, go to the secrets directory and run the following command:
```
./make_secrets_dir_template.sh acmeorg <INSERT SECURE PASSWORD HERE>
```
The response to the above command is similar to:
```
template secrets directory has been created in /home/USER/kos-buildpublish/secrets/work/acmeorg.
Fill it in with your details.  When done, you can run make_secrets_file.sh to create an encrypted 7z suitable for deployment
```

Next, go to the `secrets/work/acmeorg` folder.  This is the secrets working folder.  First, get your keysets and place them in the `keysets` subfolder.  Keysets filenames should follow the form `*.keyset`. In this case, the files *test.acme.keyset* and *prod.acme.keyset* would be installed.

For the artifact store, configure a file, `artifactstores/acmeRepo.json` as follows:
```
{
    "type": "azurecontainer",
    "studio-apikey": "INSERT APIKEY FROM STUDIO HERE",
    "container": "https://STORAGEACCOUNTNAME.blob.core.windows.net/artifacts-acme  # REPLACE Storage account and Container",
    "sastoken": "sp=racwl&st=2024-12-23T17:11:03Z&se=2025-05-11T00:11:03Z&spr=https&CENSORED # REPLACE WITH SAS TOKEN from Azure Storage Account which has access to this container",
    "marketplace": 1
}
```
(Be sure to remove the comments and fill in your details for each value)

Next, copy the `.npmrc` file to the `secrets/work/acmeorg` folder to a file called `npmrc`.  Likewise, copy the `.m2/settings.xml` needed for the build to the same folder to a file called `settings.xml`.

Finally, now that the secrets directory has been created, an encrypted secrets file can be created.  Simply run:

```
./make_secrets_file.sh acmeorg
```
Output will be similar to:
```
npmrc file found
maven settings.xml file found
keysets directory found
artifactstores directory found
usersecrets directory found
using password from secret-detail file

7-Zip [64] 16.02 : Copyright (c) 1999-2016 Igor Pavlov : 2016-05-21
p7zip Version 16.02 (locale=en_US.UTF-8,Utf16=on,HugeFiles=on,64 bits,16 CPUs Intel(R) Core(TM) i9-9900K CPU @ 3.60GHz (906EC),ASM,AES-NI)

Scanning the drive:
3 folders, 21 files, 38140 bytes (38 KiB)

Creating archive: /home/USER/kos_buildpublish/secrets/work/acmeorg-secrets.7z

Items to compress: 24

    
Files read from disk: 21
Archive size: 24920 bytes (25 KiB)
Everything is Ok
```
This will create an encrypted 7z file with a filename of `secrets/work/acmeorg-secrets.7z`.

### Sending a secrets file to an Azure Storage Account

Now that you have a secrets file, you need to make it available on a storage account for build automation.  When you define the `secrets/secret-detail/azure-token.json` file with details on the storage account, you can use command-line tools to upload secrets to the storage account.  Before doing so, you must have *azcopy* installed and in your path.  

The `azure-token.json` file can be defined with the following template (replacing the values with your own settings):
```
{
  "container": "https://STORAGEACCOUNTNAME.blob.core.windows.net/CONTAINERNAME",
  "sas": "sp=racw&st=2025-04-09T14:42:21Z&se=2025-09-01T22:42:21Z&spr=CENSORED"
}

```
The tooling will use the `azure-token.json` file to upload your encrypted secrets file to the defined Azure Storage account.  Simply run:

```
sm_put.sh acmeorg
```
Check the output to ensure the upload was successful.

### Configuring a GitHub repository with Secret Details

Each repository that is built by GitHub automation must have access to secrets. Build automation accesses the secrets by providing 2 secrets, KOSBUILD_SECRET_URL and KOSBUILD_SECRET_PASSWORD to the GitHub repository.  Automation will download the encrypted secrets from the KOSBUILD_SECRET_URL and use the KOSBUILD_SECRET_PASSWORD to decrypt the contents. (We assume that each repository will have its own secrets and that you will not necessarily be able to use organization secrets in your org).

A tool has been included which will configure a GitHub repository with your secret details such that it will work with the KOS build automation.

To use this tool, you must define a `secrets/secret-detail/github-token.json` file with contents following this template:
```
{
  "token": "ghp_CENSORED"
}
```
The token must have access to configure the secrets (I think this is either the repo or workflow permission).  Additionally, you must be an admin on each repository that you wish to configure secrets for.

Simply run:
```
./set_secrets_github.sh acmeorg MyGithubOrg MyGitHubRepo
```

### Sharing details with other DevOps team members

Tooling is available to help when secret details need to be shared with another administrator. Instead of sharing the actual build secrets, we share the password(s) for the organization's encrypted secrets, the log files, and the azure storage account details by creating an encrypted 7z file holding that data.  When extracted, the actual build secrets can be obtained by downloading the encrypted 7z files from the storage account.

To save the secret details:

```
./secret-detail-backup.sh
```

To restore the secret details
```
./secret-detail-restore.sh <filename>
```

Once you have your secret-details folder populated, you can request the actual build secrets from the storage account with:

```
./sm_get.sh <organization>
```
(You can also run `./sm_get.sh` with no arguments to get a list of organizations)
