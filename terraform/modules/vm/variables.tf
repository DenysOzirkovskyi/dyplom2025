variable "name" {
  description = "Name of the Linux virtual machine."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where VM resources are created."
  type        = string
}

variable "location" {
  description = "Azure region for VM resources."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the VM network interface is placed."
  type        = string
}

variable "admin_username" {
  description = "Admin username for SSH access."
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key used for key-based authentication."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.ssh_public_key)) > 0
    error_message = "ssh_public_key must not be empty."
  }
}

variable "vm_size" {
  description = "Azure VM size."
  type        = string
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB."
  type        = number
}

variable "os_disk_storage_account_type" {
  description = "Storage account type for the OS disk."
  type        = string
  default     = "Premium_LRS"
}

variable "public_ip_sku" {
  description = "SKU for the public IP address."
  type        = string
  default     = "Standard"
}

variable "install_docker" {
  description = "Install Docker Engine and Docker Compose plugin using cloud-init."
  type        = bool
  default     = true
}

variable "app_directory" {
  description = "Directory created on the VM for application deployment files."
  type        = string
  default     = "/opt/queue-app"
}

variable "source_image_reference" {
  description = "Azure Marketplace image used for the VM."
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

variable "tags" {
  description = "Tags applied to VM resources."
  type        = map(string)
  default     = {}
}
