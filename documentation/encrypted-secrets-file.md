# Encrypted Secrets File
 
 An encrypted secrets file contains sensitive information required for the kOS build process.  These secrets may include:
  
  1. Keyset for generating a KAB
  2. Storage account Credentials: for Azure blob store, you must have a container and an associated shared access signature (SAS) token with Create, Add, and Write Permissions.
  3. Studio Server API Key for publishing
  4. [Optional] Maven Settings file (settings.xml normally found in your ~/.m2 folder) - if required for building your code
  5. [Optional] npmrc file that configures repositories and secrets for NPM - if required for building your code
  6. [Optional] usersecrets directory can be used for any secrets/items you wish to include in your build automation that is not included in the above.  This is unstructured.

As part of the build and publish process, you must configure a folder containing your secrets.  It follows the following structure

```
   artifactstores/     [Directory containing configuration for Artifact Stores]
   keysets/            [Directory containing keysets used for KAB signing]
   usersecrets/        [Optional Directory containing secrets or files that you wish to use during the build process]
   npmrc               [Optional, npmrc file]
   settings.xml        [Optional, maven settings file]
   secrets_password    [Text file containing the password to the Secrets file]
```

This folder is then transformed into an encrypted 7z file with the provided script `make_secrets_file.sh` for use by the build process.  The secrets_password file is not included in the encrypted 7z file, but is used by tooling to create the secrets file and to run the build process locally.

Details on the secrets directory follows:

## Keyset

Keyset files are placed in the keysets/ folder.  Each keyset in this folder must be named according to its mode and authority.  For example, the test.demo keyset would be named `test.demo.keyset`.  Multiple keysets can be placed in this directory, each are referenced by name, excluding the .keyset extension.

## Artifact Stores

Artifact store definition files are defined in the artifactstores/ folder.  The naming convention of files in this directory is `<artifactstore name>.json`.  The artifact store name *must* match the repo name configured in kOS Studio.  Each artifact store definition is a JSON file. The JSON file follows the following schema:

```
Template (comments may not exist in the JSON):
{
    "type": "<type of container>",                              # [REQUIRED] Supported options: { azurecontainer }
    "studio-apikey": "<api key for publishing to Studio>",      # [REQUIRED]
    "market": <true or false>                                   # [OPTIONAL] set to true if the repo is a store for market artifacts.  Defaults to false.  This is used for garbage collection tooling.
    
    "additional_publish_servers": [                             # [OPTIONAL] add these only if you are publishing to additional servers
        {
          "server": "wss://additionalserver.com",
          "apikey": "<api key for publishing on additional server>" # additional server api key will default to "studio-apikey" if not specified
        }
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
      {
        "server": "wss://studiotest.kosdev.com"
      }
    ]
}
```

## User Secrets

Every build process is different.  If you have additional secrets that do not fit into our categories above, you can set them in the usersecrets/ folder and they will be copied out to $HOME/.kosbuild/usersecrets when the secrets are loaded.  Additionally, if you put an executable file in this folder called secrets_init, it will be run automatically after the secrets are loaded.

# Secrets file creation

A template secrets directory can be created by running the `make_secrets_dir_template.sh` script (found in the `secrets` folder of this repo). This will create the layout of the secrets directory that you can customize for your use.

Once you have customized your secrets directory, use the `make_secrets_file.sh` script to create an encrypted 7z file with your secrets.  The script takes the path to the secrets folder that you have created and an optional output filename.

```
usage: ./make_secrets_file.sh <secrets directory> [secrets-output file]
```

You must have either have a file in the secrets folder called, "secrets_password" or an environment variable, KOSBUILD_SECRETS_PASSWORD, defined when running the make_secrets_file.sh.  This password is applied to the 7z file and is required for decryption.

If you do not specify a "secrets-output file", it will output the secrets to the secrets_mount folder.  Your secrets file can then easily be used for local builds with the provided scripts.
