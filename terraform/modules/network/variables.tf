variable "name_prefix" {
  description = "Prefix used for network resource names."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where network resources are created."
  type        = string
}

variable "location" {
  description = "Azure region for network resources."
  type        = string
}

variable "address_space" {
  description = "Address space for the virtual network."
  type        = list(string)
}

variable "subnets" {
  description = "Subnets to create inside the virtual network."
  type = map(object({
    address_prefixes  = list(string)
    service_endpoints = optional(list(string), [])
  }))
}

variable "tags" {
  description = "Tags applied to network resources."
  type        = map(string)
  default     = {}
}
