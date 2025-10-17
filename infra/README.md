# Azure Infrastructure as Code

Terraform configuration for provisioning Azure infrastructure resources required for the application deployment.

## Resources Provisioned

- Azure Virtual Network with dedicated subnet for AKS
- Azure Container Registry for storing Docker images
- Azure Kubernetes Service (AKS) cluster

## Directory Structure

- `main.tf` - Main Terraform configuration file with resource definitions
- `variables.tf` - Input variable definitions
- `outputs.tf` - Output definitions
- `provider.tf` - Azure provider configuration
- `backend.tf` - State storage configuration
- `terraform.tfvars` - Variable values (gitignored for security)

## Usage

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -out=tfplan

# Apply the infrastructure changes
terraform apply tfplan

# Destroy the infrastructure when no longer needed
terraform destroy
```

## Configuration

Update `terraform.tfvars` with your specific values for:
- Resource group name
- Virtual network configuration
- AKS cluster settings
- Container registry settings

## Prerequisites

- Azure CLI installed and authenticated
- Terraform CLI installed
- Proper Azure permissions to create resources