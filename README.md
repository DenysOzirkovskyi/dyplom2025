# Queue Management System

FastAPI-based queue management application with PostgreSQL, Redis, Docker Compose, Prometheus, and Grafana. Infrastructure is provisioned in Microsoft Azure with Terraform.

## Application Runtime

The application container still runs the existing FastAPI service:

- `web`: FastAPI application exposed on port `8000` in the container.
- `db`: PostgreSQL database.
- `redis`: Redis service.
- `prometheus`: metrics collection.
- `grafana`: metrics dashboards.
- exporters: cAdvisor, Node Exporter, PostgreSQL Exporter, and Redis Exporter.

The Azure VM is prepared with Docker Engine and the Docker Compose plugin through cloud-init, so the existing `docker-compose.yml` runtime can be deployed to the VM after Terraform creates the infrastructure.

## Azure Infrastructure

Terraform creates the development environment under `terraform/environments/dev` using reusable modules:

```text
terraform/
  modules/
    network/
    nsg/
    vm/
  environments/
    dev/
      main.tf
      variables.tf
      terraform.tfvars
      outputs.tf
```

Provisioned resources include:

- Azure Resource Group
- Azure Virtual Network
- VM subnet
- Network Security Group
- NSG rules for SSH, HTTP, and HTTPS
- Public IP address
- Network Interface
- Ubuntu 24.04 LTS Linux Virtual Machine
- SSH key-only authentication
- Configurable OS disk and VM size
- Optional Azure Container Registry
- Optional Linux App Service plan
- Optional Log Analytics Workspace and Azure Monitor Agent

## Prerequisites

- Terraform `>= 1.5`
- Azure CLI
- Active Azure subscription
- SSH key pair

Authenticate with Azure:

```bash
az login
az account set --subscription "<subscription-id>"
```

Create an SSH key if needed:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/queue_azure
```

## Configure Terraform

Edit `terraform/environments/dev/terraform.tfvars` before applying:

```hcl
location = "westeurope"

ssh_allowed_cidr_ranges = ["YOUR_PUBLIC_IP/32"]
ssh_public_key          = "ssh-ed25519 YOUR_PUBLIC_KEY"

vm_size         = "Standard_B2s"
os_disk_size_gb = 64
```

Use a restricted `/32` CIDR for SSH whenever possible. HTTP and HTTPS are open through the NSG so the application can be exposed publicly after deployment.

## Deploy Azure Infrastructure

From the dev environment directory:

```bash
cd terraform/environments/dev
terraform init
terraform fmt -recursive ../..
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

After apply, Terraform prints:

- VM public IP
- VM private IP
- Resource Group name
- Virtual Network name

## SSH to the VM

Use the `vm_public_ip` output:

```bash
ssh -i ~/.ssh/queue_azure azureuser@<vm_public_ip>
```

Password authentication is disabled. Access is allowed only from the CIDR ranges configured in `ssh_allowed_cidr_ranges`.

## Deploy the Application Runtime

The VM is created with Docker installed and `/opt/queue-app` prepared for deployment files. A future GitHub Actions deployment can copy `docker-compose.yml`, `prometheus/`, `grafana/`, and `scripts/` to that directory and run:

```bash
cd /opt/queue-app
./scripts/deploy.sh
```

For manual deployment, copy the runtime files to the VM and run the same command.

Set `APP_PORT=80` in `/opt/queue-app/.env` when exposing the service through the default HTTP NSG rule:

```dotenv
APP_PORT=80
APP_IMAGE=ghcr.io/<owner>/<repo>:latest
POSTGRES_USER=queue_user
POSTGRES_PASSWORD=change-me
POSTGRES_DB=queue_db
```

## CI/CD

The repository workflow validates Terraform formatting and configuration, then builds and pushes the application Docker image to GitHub Container Registry.

Future Azure automation can add `terraform plan` and `terraform apply` jobs using Azure federated credentials or service principal credentials.
