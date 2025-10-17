# Azure Cloud Application Deployment

This repository contains all necessary components for deploying a Node.js application to Azure Kubernetes Service (AKS) using infrastructure as code principles.

## Project Structure

- **application/** - Node.js Express application with Docker containerization
- **helm-chart/** - Helm charts for Kubernetes deployment configuration
- **infra/** - Terraform code for provisioning Azure infrastructure resources

## Key Components

1. **Application**: A production-ready Node.js Express application with logging, security, and health checks
2. **Infrastructure**: Terraform code to provision AKS cluster, virtual network, and container registry
3. **Deployment**: Helm charts for Kubernetes deployment with autoscaling, ingress, and service definitions

## Getting Started

1. Set up Azure credentials
2. Provision infrastructure using Terraform
3. Build and push the Docker image
4. Deploy the application using Helm

See individual directories for detailed documentation.