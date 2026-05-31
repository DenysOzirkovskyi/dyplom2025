output "vm_id" {
  description = "ID of the Linux virtual machine."
  value       = azurerm_linux_virtual_machine.this.id
}

output "vm_name" {
  description = "Name of the Linux virtual machine."
  value       = azurerm_linux_virtual_machine.this.name
}

output "public_ip" {
  description = "Public IP address assigned to the VM."
  value       = azurerm_public_ip.this.ip_address
}

output "private_ip" {
  description = "Private IP address assigned to the VM NIC."
  value       = azurerm_network_interface.this.private_ip_address
}

output "network_interface_id" {
  description = "ID of the VM network interface."
  value       = azurerm_network_interface.this.id
}
