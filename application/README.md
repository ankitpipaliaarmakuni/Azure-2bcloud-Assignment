# Node.js Express Application

A production-ready Node.js Express application designed for containerized deployment to Azure Kubernetes Service.

## Features

- Express web server with health check endpoint
- Security middleware (helmet, cors)
- Logging with Winston and Morgan
- Compression for optimized responses
- Docker containerization
- CPU stress endpoints for testing scalability

## Directory Structure

- `src/` - Application source code
  - `app.js` - Main application entry point
- `Dockerfile` - Container image definition
- `package.json` - Node.js dependencies and scripts

## Docker Build

```bash
docker build -t your-registry/demo-app:tag .
docker push your-registry/demo-app:tag
```

## Endpoints

- `GET /` - Root endpoint returning a simple greeting
- `GET /healthz` - Health check endpoint with memory and uptime metrics
- `GET /stress` - Non-blocking CPU load simulation (accepts `chunks` parameter)

## Deployment Scripts

This application is part of a larger project that includes deployment automation and testing tools:

### Local Deployment Script (`deploy-local.ps1`)

A PowerShell script that handles the end-to-end deployment process:

```powershell
# From the root directory
./deploy-local.ps1
```

**Features:**
- Checks for required tools (az, terraform, docker, kubectl, helm)
- Sets up Azure infrastructure using Terraform
- Builds and pushes Docker image to Azure Container Registry
- Configures kubectl with AKS credentials
- Deploys the application to Kubernetes using Helm
- Deploys to dedicated "app" namespace (creates if not exists)

**Requirements:**
- PowerShell
- Azure CLI (logged in)
- Terraform
- Docker
- kubectl
- Helm

**Configuration:**
- The script will use the terraform.tfvars file in the infra directory
- Prompts for Azure subscription selection
- Uses existing resource group from terraform.tfvars or creates if needed

### Stress Test Script (`stress-test.ps1`)

A PowerShell script to test the Horizontal Pod Autoscaler (HPA) by generating load:

```powershell
# From the root directory
./stress-test.ps1
```

**Features:**
- Interactive configuration of test parameters
- Sends parallel requests to stress test endpoints
- Monitors HPA metrics during the test (CPU, memory usage)
- Displays scaling activity in real-time
- Shows request statistics and final pod count

**Test Options:**
- CPU-intensive stress test (uses `/stress` endpoint)
- Light stress test (uses `/stress-light` endpoint)
- Configurable test parameters:
  - Number of concurrent requests
  - Test duration
  - Endpoint-specific parameters (duration or chunks)

**Usage:**
1. Run the script: `./stress-test.ps1`
2. Enter the application URL when prompted (include the complete URL with endpoint)
3. Choose the test type and configure parameters
4. Monitor the output to see how the application scales under load