# Azure AKS Simple Application

This repository contains all necessary components for deploying a Node.js application to Azure Kubernetes Service (AKS) using infrastructure as code principles.

## 📋 Project Structure

```
├── application/             # Node.js Express application
│   ├── src/                 # Source code
│   │   └── app.js          # Main application entry point
│   ├── Dockerfile           # Containerization
│   ├── package.json         # Node.js dependencies
│   └── README.md            # Application documentation
├── helm-chart/              # Kubernetes deployment
│   ├── templates/           # K8s resource templates
│   │   ├── deployment.yaml  # Main deployment config
│   │   ├── hpa.yaml         # Horizontal Pod Autoscaler
│   │   ├── ingress.yaml     # Ingress configuration
│   │   └── service.yaml     # Service configuration
│   ├── Chart.yaml           # Helm chart definition
│   ├── values.yaml          # Configuration values
│   └── README.md            # Helm chart documentation
├── infra/                   # Terraform Infrastructure as Code
│   ├── main.tf              # Main Terraform configuration
│   ├── variables.tf         # Variable definitions
│   ├── outputs.tf           # Output definitions
│   ├── provider.tf          # Provider configuration
│   ├── backend.tf           # State backend configuration
│   ├── terraform.tfvars     # Variable values
│   └── README.md            # Infrastructure documentation
├── deploy-local.ps1         # Local deployment script
├── stress-test.ps1          # HPA testing script
└── README.md                # Main documentation
```

## 🚀 Key Components

1. **Application**: A Node.js Express application with:
   - � Health check endpoint (`/healthz`)
   - ⚡ Stress testing endpoints (`/stress` and `/stress-light`)
   - 🌍 Simple web interface

2. **Infrastructure**: Terraform code to provision:
   - 🧩 Azure Kubernetes Service (AKS)
   - 🔄 Azure Container Registry (ACR)
   - 🌐 Virtual Network with dedicated subnet for AKS

3. **Deployment**: Helm charts for Kubernetes with:
   - 📊 Horizontal Pod Autoscaler (HPA)
   - 🚪 Ingress configuration
   - 🧰 Resource limits and requests
   - 💓 Health probes

## 🏁 Getting Started

### Prerequisites

- Azure account and subscription
- Installed tools:
  - Azure CLI
  - Terraform
  - Docker
  - Kubectl
  - Helm

### Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/azure-aks-simple-app.git
   cd azure-aks-simple-app
   ```

2. **Run the local deployment script**
   ```powershell
   ./deploy-local.ps1
   ```
   
   This script will:
   - ✅ Check for required tools
   - 🔑 Log into Azure
   - 🏗️ Deploy infrastructure with Terraform
   - 🐳 Build and push Docker image
   - 🚢 Deploy to AKS with Helm in the "app" namespace

3. **Test the Horizontal Pod Autoscaler**
   ```powershell
   ./stress-test.ps1
   ```
   
   This script will:
   - Generate load on your application
   - Monitor HPA scaling activity
   - Display test statistics

## 🛠️ Manual Deployment Steps

If you prefer to deploy manually, follow these steps:

### 1. Set up Azure Infrastructure

```bash
cd infra
terraform init
terraform apply
```

### 2. Build and Push Docker Image

```bash
cd application
az acr login --name <your-acr-name>
docker build -t <your-acr-name>.azurecr.io/demo-app:v1 .
docker push <your-acr-name>.azurecr.io/demo-app:v1
```

### 3. Deploy with Helm

```bash
kubectl create namespace app
cd helm-chart
helm install my-app . -n app
```

## 🔄 CI/CD with GitHub Actions

This repository can be set up with GitHub Actions for CI/CD.

### Setting up GitHub Actions

1. Create an Azure Service Principal following [the guide](docs/service-principal-setup.md)
2. Add the following secrets to your GitHub repository:
   - `AZURE_CREDENTIALS`: Service principal credentials in JSON format
   - `SUBSCRIPTION_ID`: Your Azure subscription ID

## 📚 Additional Documentation

- [Service Principal Setup](docs/service-principal-setup.md)
- [Application Documentation](application/README.md) - Contains details about the application endpoints and features
- [Deployment Script](deploy-local.ps1) - Local deployment automation
- [Stress Test Script](stress-test.ps1) - HPA testing tool

## 📊 Key Scripts

### Local Deployment Script (`deploy-local.ps1`)

A PowerShell script that handles the end-to-end deployment process:

**Features:**
- Checks for required tools (az, terraform, docker, kubectl, helm)
- Sets up Azure infrastructure using Terraform
- Builds and pushes Docker image to Azure Container Registry
- Configures kubectl with AKS credentials
- Deploys the application to Kubernetes using Helm in the "app" namespace

### Stress Test Script (`stress-test.ps1`)

A PowerShell script to test the Horizontal Pod Autoscaler (HPA) by generating load:

**Features:**
- Interactive configuration of test parameters
- Sends parallel requests to stress test endpoints
- Monitors HPA metrics during the test
- Displays scaling activity in real-time
- Shows request statistics and final pod count

## 🔧 Troubleshooting

Common issues and solutions:

| Issue | Solution |
|-------|----------|
| Connection timeout | Check network security groups |
| Image pull errors | Verify ACR credentials are set up |
| Pod crash loops | Check logs with `kubectl logs -n app` |
| Permission errors | Verify RBAC configuration |

---

Happy deploying on Azure Cloud!