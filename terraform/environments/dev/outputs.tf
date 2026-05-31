output "resource_group_name" {
  description = "Name of the Azure Resource Group."
  value       = azurerm_resource_group.this.name
}

output "vnet_name" {
  description = "Name of the Azure Virtual Network."
  value       = module.network.vnet_name
}

output "vm_public_ip" {
  description = "Public IP address of the Linux VM."
  value       = module.vm.public_ip
}

output "vm_private_ip" {
  description = "Private IP address of the Linux VM."
  value       = module.vm.private_ip
}

output "vm_name" {
  description = "Name of the Linux VM."
  value       = module.vm.vm_name
}

output "container_registry_login_server" {
  description = "Login server for Azure Container Registry, if enabled."
  value       = var.enable_container_registry ? azurerm_container_registry.this[0].login_server : null
}

output "app_service_plan_id" {
  description = "ID of the Linux App Service plan, if enabled."
  value       = var.enable_app_service_plan ? azurerm_service_plan.this[0].id : null
}

output "log_analytics_workspace_id" {
  description = "Workspace ID for Log Analytics, if enabled."
  value       = var.enable_log_analytics ? azurerm_log_analytics_workspace.this[0].workspace_id : null
}
