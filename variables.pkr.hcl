# Azure ARM Variables
variable "subscription_id" {
  description = "The Azure subscription ID to use for building the image"
  type        = string
}

variable "location" {
  description = "Azure region where the resources will be deployed"
  type        = string
  default     = "uksouth"
}

variable "image_resource_group_name" {
  description = "Name of the resource group in which the Packer image will be created"
  type        = string
}

variable "image_publisher" {
  description = "Publisher of the base image"
  type        = string
  default     = "Canonical"
}

variable "image_offer" {
  description = "Offer of the base image"
  type        = string
  default     = "0001-com-ubuntu-server-jammy"
}

variable "image_sku" {
  description = "SKU of the base image"
  type        = string
  default     = "22_04-lts-arm64"
}

variable "os_type" {
  description = "Type of operating system"
  type        = string
  default     = "Linux"
}

variable "gallery_name" {
  description = "Name of the shared image gallery"
  type        = string
  default     = "arm64"
}

variable "image_name" {
  description = "Name of the image in the shared image gallery"
  type        = string
  default     = "dsbd-ubuntu-22.04-lts"
}

variable "image_version" {
  description = "Version of the image in the shared image gallery"
  type        = string
  default     = "0.0.1"
}

variable "storage_account_type" {
  description = "Type of storage account for the managed image"
  type        = string
  default     = "Standard_LRS"
}

variable "vm_size" {
  description = "Size of the VM used for building the image"
  type        = string
  default     = "Standard_D2pds_v5"
}
# Common Variables

variable "ssh_username" {
  description = "The username for SSH access"
  type        = string
  default     = "packer"
}

variable "ssh_password" {
  description = "A plaintext password to use to authenticate with SSH"
  type        = string
  default     = "packer"
}

variable "ssh_timeout" {
  description = "The time to wait for SSH to become available"
  type        = string
  default     = "20m"
}

# Add additional variables as needed
