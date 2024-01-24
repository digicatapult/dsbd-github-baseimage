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

You will need to provide some vars, namely, the resource group and the subscription id which have been purposefully omitted from the repo as they are considered secret, these can be loaded automatically from a file called `secrets.auto.pkrvars.hcl` in the root of the repo.

Run using `packer build .` in the root of the repo.
