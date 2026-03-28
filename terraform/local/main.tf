terraform {
  required_version = ">= 1.5.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

locals {
  project_root = abspath("${path.module}/../..")
}

resource "null_resource" "vagrant_up" {
  triggers = {
    always_run      = timestamp()
    vagrantfile_hash = filesha256("${local.project_root}/Vagrantfile")
  }

  provisioner "local-exec" {
    working_dir = local.project_root
    command     = "vagrant up --provider=virtualbox"
  }
}

resource "null_resource" "vagrant_destroy" {
  triggers = {
    project_root = local.project_root
  }

  provisioner "local-exec" {
    when        = destroy
    working_dir = self.triggers.project_root
    command     = "vagrant destroy -f"
  }
}

output "vm_ip" {
  description = "Private IP address of the Vagrant VM."
  value       = "192.168.56.10"
}

output "app_url" {
  description = "Application URL exposed on the host machine."
  value       = "http://127.0.0.1:8080"
}

output "grafana_url" {
  description = "Grafana URL exposed on the host machine."
  value       = "http://127.0.0.1:3000"
}

output "prometheus_url" {
  description = "Prometheus URL exposed on the host machine."
  value       = "http://127.0.0.1:9090"
}
