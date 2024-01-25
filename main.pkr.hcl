packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

# Cloud-init configuration files
source "file" "user_data" {
  content = <<-EOF
    #cloud-config
    user: ${var.ssh_username}
    password: ${var.ssh_password}
    chpasswd: { expire: False }
    ssh_pwauth: True
  EOF
  target  = "user-data"
}

source "file" "meta_data" {
  content = <<-EOF
    instance-id: ubuntu-cloud
    local-hostname: ubuntu-cloud
  EOF
  target  = "meta-data"
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

# Build Process
build {
  sources = ["source.azure-arm.ubuntu"]

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
  # This is to deal with Azure being blacklisted by the gmp mercurial server, so we use a github mirror instead.
  provisioner "file" {
    source      = "./files/cheribuild-gmp-git.patch"
    destination = "/tmp/cheribuild-gmp-git.patch"
  }
  provisioner "file" {
    source      = "./files/qemu-morello.service"
    destination = "/tmp/qemu-morello.service"
  }
  provisioner "file" {
    source      = "./files/update-qemu-morello-config.service"
    destination = "/tmp/update-qemu-morello-config.service"
  }
  provisioner "file" {
    source      = "./files/update_qemu_morello_config.sh"
    destination = "/tmp/update_qemu_morello_config.sh"
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
}
