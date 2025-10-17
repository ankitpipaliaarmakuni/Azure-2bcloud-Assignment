# Azure Cloud Application Deployment

![Azure AKS](docs/images/azure-kubernetes.gif)

This repository contains all necessary components for deploying a Node.js application to Azure Kubernetes Service (AKS) using infrastructure as code principles.

## 📋 Project Structure

```
├── application/             # Node.js Express application
│   ├── src/                 # Source code
│   └── Dockerfile           # Containerization
├── helm-chart/              # Kubernetes deployment
│   ├── templates/           # K8s resource templates
│   └── values.yaml          # Configuration values
├── infra/                   # Terraform IaC
│   ├── modules/             # Reusable modules
│   └── *.tf                 # Main configuration
├── docs/                    # Documentation
│   └── images/              # Screenshots and images
└── deploy-local.ps1         # Local deployment script
```

## 🚀 Key Components

![Architecture](docs/images/architecture-diagram.png)

1. **Application**: A production-ready Node.js Express application with:
   - 🔒 Security middleware (helmet)
   - 📝 Comprehensive logging (winston)
   - 🌍 CORS support
   - 🔍 Health checks for Kubernetes probes
   - ⚡ Stress testing endpoint

2. **Infrastructure**: Terraform code to provision:
   - 🧩 Azure Kubernetes Service (AKS)
   - 🔄 Azure Container Registry (ACR)
   - 🌐 Virtual Network with dedicated subnet for AKS
   - 🔑 RBAC with Azure AD integration

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

![Prerequisites](docs/images/prerequisites.png)

### Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/azure-aks-application.git
   cd azure-aks-application
   ```

2. **Run the deployment script**
   ```bash
   ./deploy-local.ps1
   ```
   
   This script will:
   - ✅ Check for required tools
   - 🔑 Log into Azure
   - 🏗️ Deploy infrastructure with Terraform
   - 🐳 Build and push Docker image
   - 🚢 Deploy to AKS with Helm

   ![Deployment Process](docs/images/deployment-process.gif)

## 🛠️ Manual Deployment Steps

If you prefer to deploy manually, follow these steps:

### 1. Set up Azure Infrastructure

```bash
cd infra
terraform init
terraform apply
```

![Terraform Apply](docs/images/terraform-apply.png)

### 2. Build and Push Docker Image

```bash
cd application
az acr login --name <your-acr-name>
docker build -t <your-acr-name>.azurecr.io/demo-app:v1 .
docker push <your-acr-name>.azurecr.io/demo-app:v1
```

### 3. Deploy with Helm

```bash
cd helm-chart
helm install my-app .
```

![Successful Deployment](docs/images/successful-deployment.png)

## 🔄 CI/CD with GitHub Actions

This repository can be set up with GitHub Actions for CI/CD.

### Setting up GitHub Actions

1. Create an Azure Service Principal following [the guide](docs/service-principal-setup.md)
2. Convert the service principal credentials to the format required by the Azure login action
3. Add the following secrets to your GitHub repository:
   - `AZURE_CREDENTIALS`: Service principal credentials in JSON format
   - `SUBSCRIPTION_ID`: Your Azure subscription ID (e.g., `b99c0710-ded3-407b-b632-9fb5dd7edd13`)
   
![GitHub Actions](docs/images/github-actions.png)

## 📚 Additional Documentation

- [Service Principal Setup](docs/service-principal-setup.md)
- [Application Documentation](application/README.md)
- [Helm Chart Documentation](helm-chart/README.md)
- [Infrastructure Documentation](infra/README.md)

## 📊 Monitoring and Management

After deployment, access your application and monitor it:

```bash
# Get the application endpoint
kubectl get ingress

# Check pod status
kubectl get pods

# View logs
kubectl logs deployment/my-app
```

![Monitoring Dashboard](docs/images/monitoring-dashboard.png)

## 🔧 Troubleshooting

Common issues and solutions:

| Issue | Solution |
|-------|----------|
| Connection timeout | Check network security groups |
| Image pull errors | Verify ACR credentials are set up |
| Pod crash loops | Check logs with `kubectl logs` |
| Permission errors | Verify RBAC configuration |

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

Made with ❤️ for Azure Cloud