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
    SECRET_SOURCE=azure
    SECRET_NAME=github-actions
    KEY_VAULT_NAME=dsbd-github-images
    GITHUB_ORG=dc-dsbd-test
  append: true
```

### Accessing the QEMU guest

We recommend you access the QEMU guest by using ssh.  Firstly you will need to establish a tunnel to the Ubuntu host via a bastion, in Azure this can be achieved with the following command:

```sh
az network bastion tunnel --resource-group <resource-group> --name <bastion-name> --target-resource-id <resource ID of the VM or the VMSS instance ID you wish to access> --resource-port 22 --port 2022
```
Secondly you will need to ssh to the ubuntu host using ssh-agent forwarding, this can be achieved with the following command:

```sh
ssh -A -p 2022 <username>@localhost
```

Once you have access to the ubuntu host you can ssh to the QEMU guest using the following command:

```sh
ssh -p 10005 root@localhost
```
