# README.md

## Project Description
This is a packer project to build a CheriBSD Morello [QEMU](https://github.com/CTSRD-CHERI/qemu) environment with builtin support for [Github Actions](https://github.com/actions/runner) self-hosted runners.

## Pre-requisites

* packer

* Azure or AWS account

### Development

* shellCheck

## Installation

Begin by cloning the repository

```sh
git clone https://github.com/digicatapult/dsbd-github-baseimage.git
```

## Configuration
Depending on if you are using the Azure Builder or the AWS Builder you will need to set the following in a file called `secrets.auto.pkrvars.hcl` in the root of the repo.  The file should contain the following variables:

### Azure

```sh
subscription_id = "<The Subscription ID for your Azure account>"
image_resource_group_name = "<Resource Group name for the storage account"
image_version = "<Semver compatible version number>"
```

### AWS

```sh
aws_access_key = "<Your AWS Access Key ID>"
aws_secret_key = "<Your AWS Secret Access Key>"
```

### Either
```sh
ssh_public_key = "<String representation of the public key that you use to access the CheriBSD QEMU guest>"
```

## Usage

### Azure

Login to Azure
```
az login --subscription <subscription_id>
```

Prestage the SIG image definition (If it has not already been created)

```
az sig image-definition create --resource-group <your RG name> --gallery-name <your gallery name> \
 --gallery-image-definition <your image name> --publisher Canonical --offer 0001-com-ubuntu-server-jammy \
 --sku <SKU> --os-type linux --hyper-v-generation V2 --architecture <Architecture>
```

Run packer build
```
packer build -only=azure-arm.ubuntu --var aws_access_key=blah --var aws_secret_key=blah .
```
### AWS



### Retrieving Github Actions PAT from Azure Key Vault or AWS Secrets Manager

The PAT is stored in Azure Key Vault or AWS Secrets Manager.  The PAT is used to authenticate to Github and retrieve a token for registering a self served Github Actions runner.  Using cloudInit please provide the following ENVARS for the `update_qemu_morello_config.sh` script to retrieve the PAT from the respective secret store.  We suggest using cloudinit to write the environment variables to `/etc/sysconfig/update-qemu-morello-config.conf` so that they are available to the `update_qemu_morello_config.sh` script.

```yaml
#cloud-config
write_files:
- path: /etc/sysconfig/update-qemu-morello-config.conf
  content: |
    SECRET_SOURCE=azure
    SECRET_NAME=github-actions
    KEY_VAULT_NAME=dsbd-github-images
    GITHUB_ORG=dc-dsbd-test
  append: true
```

### Accessing the QEMU guest

We recommend you access the QEMU guest by using ssh, you will need to have the corresponding private key to the public key that you used when building the image.

You will need to use `ssh-agent` forwarding to pass the key to the QEMU guest.  To do this you will need to add the key to your ssh-agent using the following command:

```sh
ssh -A <username>@<host>
```

 Once you have access to the ubuntu host you can ssh to the QEMU guest using the following command:

```sh
ssh -p 10005 root@localhost
```
