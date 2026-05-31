project_name = "queue"
environment  = "dev"
location     = "austriaeast"

subscription_id = "946ed033-466b-4bc5-86d1-b667bb4d9c6f"

vnet_address_space         = ["10.20.0.0/16"]
vm_subnet_address_prefixes = ["10.20.1.0/24"]

ssh_allowed_cidr_ranges = ["0.0.0.0/0"]

admin_username               = "azureuser"
ssh_public_key               = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDh6S9ThfN0mNBA+pONfJ3QbR7WuxmaECX0OXhPXUo6qFdu7sM1yh2UPeLt6hMktaYcqbJlz+EQku3YCIfinvBRrkzR3CQBAi5wvH1KDMPQ0A2g9pZV+2kZz/HN2qg6KDMIIvgYZ+ddtt5GyOEfKgk1Vnlj+8FfAcvD69vtN8SRpdFYHWGKbsOHM5ROwvK0KWY66MQW/DPNgquC2WfZyVcV/FdXKr+wqE2CydKJcXGUNt269GNUfm9TMXo66c5UFTUSFz6VZ3bcXkfKmC9iH2uCiNJHFywqhJqhWQttTHMijKgQsdEN0hFtE1etA+rAYKam65KozugFjSRsIKeyoqALw7WAGs+I0CnHw8dmA9LnTMUv7yB8fUp/iBTwjavaqNpftcHw5Z/1g50+1qsMY4I1C/+wTHA5EQHWMw2VyfInrip+XrIl1Pvvv0lj9alObrU/jppIN2H2IZEwO7y4fjhd5FBtfi1XWAnLt27RGQU0+ck/BIo1n7U8H/T/0GyHHrD3LsVgb3YXpLb9kknMpMdDPTWX5QqhoDh5f/Ya88/7EWkXd3G/PfoBdMZn2FZ+WrZ6NVFLkNdUDe9ImB6Cs29HUluXrGbDe/7GPziEZw5C0XRbdZn2kwO8l4XK0Jiusdqa/q+6El8hWf/UMZki6EihIeH5uJUOdqL+SrShQPLV+Q== queue-azure-rsa"
vm_size                      = "Standard_B2ls_v2"
os_disk_size_gb              = 30
os_disk_storage_account_type = "Standard_LRS"

install_docker = true
app_directory  = "/opt/queue-app"

enable_container_registry = false
container_registry_name   = null
container_registry_sku    = "Basic"

enable_app_service_plan = false
app_service_plan_sku    = "B1"

enable_log_analytics = false
enable_vm_monitoring = false

tags = {
  Owner = "diploma"
}
