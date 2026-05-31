variable "name" {
  description = "Name of the Network Security Group."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where the NSG is created."
  type        = string
}

variable "location" {
  description = "Azure region for the NSG."
  type        = string
}

variable "security_rules" {
  description = "Security rules to attach to the NSG."
  type = map(object({
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
    description                = optional(string)
  }))
  default = {}
}

variable "subnet_ids" {
  description = "Subnet IDs associated with this NSG."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to NSG resources."
  type        = map(string)
  default     = {}
}
