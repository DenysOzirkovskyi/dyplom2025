variable "project_name" {
  description = "Short project name used in Azure resource names."
  type        = string
  default     = "queue"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID where Terraform creates resources."
  type        = string
}

variable "vnet_address_space" {
  description = "CIDR address space for the Azure virtual network."
  type        = list(string)
}

variable "vm_subnet_address_prefixes" {
  description = "CIDR address prefixes for the VM subnet."
  type        = list(string)
}

variable "ssh_allowed_cidr_ranges" {
  description = "CIDR ranges allowed to connect to the VM over SSH."
  type        = list(string)

  validation {
    condition     = length(var.ssh_allowed_cidr_ranges) > 0
    error_message = "At least one SSH source CIDR must be provided."
  }
}

variable "admin_username" {
  description = "Admin username for the Linux VM."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key for Linux VM authentication."
  type        = string
  sensitive   = true
}

variable "vm_size" {
  description = "Azure VM size."
  type        = string
  default     = "Standard_B1s"
}

variable "os_disk_size_gb" {
  description = "Linux VM OS disk size in GB."
  type        = number
  default     = 30
}

variable "os_disk_storage_account_type" {
  description = "Storage account type for the VM OS disk."
  type        = string
  default     = "Standard_LRS"
}

variable "install_docker" {
  description = "Install Docker Engine and Docker Compose plugin on the VM using cloud-init."
  type        = bool
  default     = true
}

variable "app_directory" {
  description = "Directory created on the VM for application deployment files."
  type        = string
  default     = "/opt/queue-app"
}

variable "enable_container_registry" {
  description = "Create Azure Container Registry."
  type        = bool
  default     = true
}

variable "container_registry_name" {
  description = "Globally unique Azure Container Registry name. Leave null to derive one from project and environment."
  type        = string
  default     = null
}

variable "container_registry_sku" {
  description = "SKU for Azure Container Registry."
  type        = string
  default     = "Basic"
}

variable "enable_app_service_plan" {
  description = "Create a Linux App Service plan for future PaaS deployment."
  type        = bool
  default     = true
}

variable "app_service_plan_sku" {
  description = "SKU for the Linux App Service plan."
  type        = string
  default     = "B1"
}

variable "enable_log_analytics" {
  description = "Create Log Analytics Workspace."
  type        = bool
  default     = true
}

variable "enable_vm_monitoring" {
  description = "Install Azure Monitor Agent and associate a performance counter data collection rule with the VM."
  type        = bool
  default     = true
}

variable "log_analytics_sku" {
  description = "SKU for Log Analytics Workspace."
  type        = string
  default     = "PerGB2018"
}

variable "log_analytics_retention_days" {
  description = "Retention period for Log Analytics data."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Additional tags applied to all supported resources."
  type        = map(string)
  default     = {}
}
