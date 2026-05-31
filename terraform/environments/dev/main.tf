terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

locals {
  name_prefix = lower(replace("${var.project_name}-${var.environment}", "_", "-"))
  tags = merge(
    var.tags,
    {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  )

  vm_subnets = {
    vm = {
      address_prefixes = var.vm_subnet_address_prefixes
    }
  }

  ssh_rules = {
    for index, cidr in var.ssh_allowed_cidr_ranges : "allow-ssh-${index + 1}" => {
      priority                   = 100 + index
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = cidr
      destination_address_prefix = "*"
      description                = "Allow SSH from approved CIDR ${cidr}."
    }
  }

  web_rules = {
    allow-http = {
      priority                   = 200
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = "Allow inbound HTTP traffic."
    }
    allow-https = {
      priority                   = 210
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = "Allow inbound HTTPS traffic."
    }
  }

  acr_name = coalesce(var.container_registry_name, substr(replace("${local.name_prefix}acr", "-", ""), 0, 50))
}

resource "azurerm_resource_group" "this" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.tags
}

module "network" {
  source = "../../modules/network"

  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = var.vnet_address_space
  subnets             = local.vm_subnets
  tags                = local.tags
}

module "vm_nsg" {
  source = "../../modules/nsg"

  name                = "${local.name_prefix}-vm-nsg"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  security_rules      = merge(local.ssh_rules, local.web_rules)
  subnet_ids          = [module.network.subnet_ids["vm"]]
  tags                = local.tags
}

module "vm" {
  source = "../../modules/vm"

  name                         = "${local.name_prefix}-vm"
  resource_group_name          = azurerm_resource_group.this.name
  location                     = azurerm_resource_group.this.location
  subnet_id                    = module.network.subnet_ids["vm"]
  admin_username               = var.admin_username
  ssh_public_key               = var.ssh_public_key
  vm_size                      = var.vm_size
  os_disk_size_gb              = var.os_disk_size_gb
  os_disk_storage_account_type = var.os_disk_storage_account_type
  install_docker               = var.install_docker
  app_directory                = var.app_directory
  tags                         = local.tags

  depends_on = [module.vm_nsg]
}

resource "azurerm_container_registry" "this" {
  count = var.enable_container_registry ? 1 : 0

  name                = local.acr_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = var.container_registry_sku
  admin_enabled       = false
  tags                = local.tags
}

resource "azurerm_service_plan" "this" {
  count = var.enable_app_service_plan ? 1 : 0

  name                = "${local.name_prefix}-asp"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  os_type             = "Linux"
  sku_name            = var.app_service_plan_sku
  tags                = local.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  count = var.enable_log_analytics ? 1 : 0

  name                = "${local.name_prefix}-law"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_analytics_retention_days
  tags                = local.tags
}

resource "azurerm_virtual_machine_extension" "azure_monitor_agent" {
  count = var.enable_log_analytics && var.enable_vm_monitoring ? 1 : 0

  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = module.vm.vm_id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.33"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
  tags                       = local.tags
}

resource "azurerm_monitor_data_collection_rule" "vm" {
  count = var.enable_log_analytics && var.enable_vm_monitoring ? 1 : 0

  name                = "${local.name_prefix}-vm-dcr"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = local.tags

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.this[0].id
      name                  = "log-analytics"
    }
  }

  data_flow {
    streams      = ["Microsoft-Perf"]
    destinations = ["log-analytics"]
  }

  data_sources {
    performance_counter {
      name                          = "vm-performance-counters"
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "\\Processor(_Total)\\% Processor Time",
        "\\Memory\\Available MBytes",
        "\\LogicalDisk(_Total)\\% Free Space"
      ]
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "vm" {
  count = var.enable_log_analytics && var.enable_vm_monitoring ? 1 : 0

  name                    = "${local.name_prefix}-vm-dcra"
  target_resource_id      = module.vm.vm_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vm[0].id

  depends_on = [azurerm_virtual_machine_extension.azure_monitor_agent]
}
