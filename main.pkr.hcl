packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

# Azure ARM Builder configuration
source "azure-arm" "ubuntu" {
  use_azure_cli_auth = true
  subscription_id    = var.subscription_id
  location           = var.location
  image_publisher    = var.image_publisher
  image_offer        = var.image_offer
  image_sku          = var.image_sku
  os_type            = var.os_type
  os_disk_size_gb    = var.os_disk_size_gb
  shared_image_gallery_destination {
    resource_group       = var.image_resource_group_name
    gallery_name         = var.gallery_name
    image_name           = var.image_name
    image_version        = var.image_version
    storage_account_type = var.storage_account_type
  }
  vm_size             = var.vm_size
}

# AWS EBS Builder configuration
source "amazon-ebs" "ubuntu" {
  access_key           = var.aws_access_key
  secret_key           = var.aws_secret_key
  region               = var.aws_region
  source_ami_filter {
    filters = {
      name                = var.aws_source_ami_name
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners = [var.aws_source_ami_owner]
    most_recent = true
  }
  instance_type        = var.aws_instance_type
  ssh_username         = var.aws_ssh_username
  ami_name             = "${var.aws_ami_name}-{{timestamp}}"
  launch_block_device_mappings {
    device_name = "/dev/sda1"
    volume_size          = var.os_disk_size_gb
  }
}

# Build Process
build {
  sources = ["source.azure-arm.ubuntu", "source.amazon-ebs.ubuntu"]

  # Cloud-init may still be running when we start executing scripts
  # To avoid race conditions, make sure cloud-init is done first
  provisioner "shell" {
    inline = [
      "echo '==> Waiting for cloud-init to finish'",
      "/usr/bin/cloud-init status --wait",
      "echo '==> Cloud-init complete'",
    ]
  }

  provisioner "shell-local" {
    inline = ["mkisofs -output cidata.iso -input-charset utf-8 -volid cidata -joliet -r user-data meta-data"]
  }

  # Patch qemu to allow multicore ARM64 emulation
  provisioner "file" {
    source      = "./files/qemu-multicore.patch"
    destination = "/tmp/qemu-multicore.patch"
  }
  provisioner "file" {
    source      = "./files/cheribuild.json"
    destination = "/tmp/cheribuild.json"
  }
  provisioner "file" {
    source      = "./files/qemu-morello.service"
    destination = "/tmp/qemu-morello.service"
  }
  provisioner "file" {
    content     = "${var.ssh_public_key}"
    destination = "/tmp/dsbd_labs.pub"
  }
  provisioner "file" {
    source      = "./files/update-qemu-morello-config.service"
    destination = "/tmp/update-qemu-morello-config.service"
  }
  provisioner "file" {
    source      = "./files/update_qemu_morello_config.sh"
    destination = "/tmp/update_qemu_morello_config.sh"
  }
  provisioner "file" {
    source      = "./files/create-qemu-release-pipeline.service"
    destination = "/tmp/create-qemu-release-pipeline.service"
  }
  provisioner "file" {
    source      = "./files/create_qemu_release_pipeline.sh"
    destination = "/tmp/create_qemu_release_pipeline.sh"
  }
  provisioner "file" {
    source      = "./files/extra-files"
    destination = "/tmp/extra-files/"
  }
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
    script = "./scripts/install-cheribuild.sh"
  }
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
    script = "./scripts/create-cheribsd-image.sh"
  }
  provisioner "shell" {
    only = ["azure-arm.ubuntu"]
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y",
      "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
    ]
  }
  provisioner "shell" {
    only = ["amazon-ebs.ubuntu"]  # Specifies that this provisioner runs only for the AWS build
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "apt-get update",  # Updates the list of available packages
      "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y",  # Upgrades all the installed packages

      # AWS specific cleanup and preparation commands
      # (replace or remove these with commands relevant to your use case)
      "sudo cloud-init clean --logs",  # Cleans up cloud-init artifacts and logs
      "echo 'AWS-specific commands or cleanup'",

      # The following commands are often used in AWS to prepare an instance for AMI creation
      "sudo rm -rf /var/lib/cloud/instances/*",  # Remove cloud-init instance data
      "sudo rm -rf /var/log/cloud-init*.log",    # Clean up cloud-init logs
      "sudo rm -rf /var/log/awslogs.log",        # Clean up awslogs
      "export HISTSIZE=0 && sync"                # Clear history and sync to disk
    ]
  }
}
