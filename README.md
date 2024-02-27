# README.md

## Pre-requisites
packer

clone the repository

## Build the image

Login to Azure

az login --subscription <subscription_id>

Prestage the SIG image definition (If it has not already been created)

```
az sig image-definition create --resource-group dsbd-github-images --gallery-name arm64 \
 --gallery-image-definition dsbd-ubuntu-22.04-lts --publisher Canonical --offer 0001-com-ubuntu-server-jammy \
 --sku 22_04-lts-arm64 --os-type linux --hyper-v-generation V2 --architecture Arm64
```

You will need to provide some vars, namely, the resource group and the subscription id which have been purposefully omitted from the repo as they are considered secret, these can be loaded automatically from a file called `secrets.auto.pkrvars.hcl` in the root of the repo.  You will also need to supply the AWS credentials in the same file, e.g. aws_access_key and aws_secret_key.

Run using `packer build .` in the root of the repo.

To only run one of the sources e.g. the aws source, use `packer build -only=amazon-ebs.ubuntu .`

### Retrieving Github Actions PAT from Azure Key Vault or AWS Secrets Manager

The PAT is stored in Azure Key Vault or AWS Secrets Manager.  The PAT is used to authenticate to Github and retrieve a token for registering a self served Github Actions runner.  Using cloudInit please provide the following ENVARS for the `update_qemu_morello_config.sh` script to retrieve the PAT from the respective secret store.  We suggest using cloudinit to write the environment variables to `/etc/environment` so that they are available to the `update_qemu_morello_config.sh` script.

```yaml
#cloud-config
write_files:
- path: /etc/sysconfig/update-qemu-morello-config.conf
  content: |
    SECRET_SOURCE=azure # or aws
    SECRET_NAME=github-actions # or the name of the secret in the respective secret store
    KEY_VAULT_NAME=dsbd-github-images # the name of the key vault, only required for Azure
    GITHUB_ORG=dc-dsbd-test # the name of the github org
  append: true
```
