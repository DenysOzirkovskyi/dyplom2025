variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
  default     = "rg-dyplom2025"
}

variable "location" {
  type        = string
  description = "Azure region"
  default     = "East US"
}

variable "vm_admin_username" {
  type        = string
  description = "Admin username for the VM"
  default     = "azureuser"
}

variable "ssh_public_key" {
  type        = string
  description = "Public SSH key for VM authentication"
}
