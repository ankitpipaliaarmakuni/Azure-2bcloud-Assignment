#!/usr/bin/env pwsh
# Deployment script for AKS application - Infrastructure, Application, and Helm
# This script checks for required tools, logs into Azure, and handles deployment

#############################################################
# Checking pre-requisites
#############################################################

function Check-Command {
    param (
        [string]$CommandName,
        [string]$InstallInstructions
    )
    
    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        Write-Host "✅ $CommandName is installed" -ForegroundColor Green
        return $true
    } else {
        Write-Host "❌ $CommandName is not installed" -ForegroundColor Red
        Write-Host $InstallInstructions -ForegroundColor Yellow
        return $false
    }
}

function Check-AzLogin {
    try {
        $context = az account show | ConvertFrom-Json
        if ($context) {
            Write-Host "✅ Logged into Azure as $($context.user.name) in subscription $($context.name)" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "❌ Not logged into Azure" -ForegroundColor Red
        return $false
    }
}

Write-Host "
#########################################################
# Checking required tools for AKS Application Deployment
#########################################################
" -ForegroundColor Cyan

# Check Azure CLI
$azCliInstall = "To install Azure CLI, visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
$azCliInstalled = Check-Command -CommandName "az" -InstallInstructions $azCliInstall

# Check Terraform
$terraformInstall = "To install Terraform, visit: https://learn.hashicorp.com/tutorials/terraform/install-cli"
$terraformInstalled = Check-Command -CommandName "terraform" -InstallInstructions $terraformInstall

# Check Docker
$dockerInstall = "To install Docker Desktop, visit: https://www.docker.com/products/docker-desktop"
$dockerInstalled = Check-Command -CommandName "docker" -InstallInstructions $dockerInstall

# Check kubectl
$kubectlInstall = "To install kubectl, visit: https://kubernetes.io/docs/tasks/tools/install-kubectl/"
$kubectlInstalled = Check-Command -CommandName "kubectl" -InstallInstructions $kubectlInstall

# Check Helm
$helmInstall = "To install Helm, visit: https://helm.sh/docs/intro/install/"
$helmInstalled = Check-Command -CommandName "helm" -InstallInstructions $helmInstall

# Check if all required tools are installed
if (-not ($azCliInstalled -and $terraformInstalled -and $dockerInstalled -and $kubectlInstalled -and $helmInstalled)) {
    Write-Host "`nPlease install all required tools before proceeding." -ForegroundColor Red
    exit 1
}

# Check Azure login
if (-not (Check-AzLogin)) {
    Write-Host "Please log in to Azure using 'az login'" -ForegroundColor Yellow
    az login
    
    if (-not (Check-AzLogin)) {
        Write-Host "Failed to log in to Azure. Exiting." -ForegroundColor Red
        exit 1
    }
}

#############################################################
# Ask for deployment parameters
#############################################################

Write-Host "`n
#########################################################
# Deployment Configuration
#########################################################
" -ForegroundColor Cyan

# Get subscription to use
$subscriptions = az account list | ConvertFrom-Json
if ($subscriptions.Count -gt 1) {
    Write-Host "Multiple subscriptions found, please select one:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $subscriptions.Count; $i++) {
        Write-Host "[$i] $($subscriptions[$i].name) (ID: $($subscriptions[$i].id))"
    }
    
    $subscriptionIndex = Read-Host "Enter the index of the subscription to use"
    $subscription = $subscriptions[$subscriptionIndex]
    az account set --subscription $subscription.id
    
    Write-Host "Using subscription: $($subscription.name)" -ForegroundColor Green
} else {
    Write-Host "Using subscription: $($subscriptions[0].name)" -ForegroundColor Green
    $subscription = $subscriptions[0]
}

# The script is in the root directory of the project
$rootDir = $PSScriptRoot
$infraDir = Join-Path -Path $rootDir -ChildPath "infra"
Write-Host "Infra directory: $infraDir" -ForegroundColor Yellow

# Define tfVarsPath
$tfVarsPath = Join-Path -Path $infraDir -ChildPath "terraform.tfvars"
Write-Host "Checking for terraform.tfvars at path: $tfVarsPath" -ForegroundColor Yellow
$fileExists = Test-Path $tfVarsPath
Write-Host "File exists: $fileExists" -ForegroundColor Yellow

# Set the default location if not provided
$defaultLocation = "eastus"
$location = Read-Host "Enter Azure region to deploy to (default: $defaultLocation)"
if ([string]::IsNullOrWhiteSpace($location)) {
    $location = $defaultLocation
}

# Extract resource group name from terraform.tfvars if it exists
if (Test-Path $tfVarsPath) {
    $tfVarsContent = Get-Content -Path $tfVarsPath -Raw
    if ($tfVarsContent -match 'resource_group_name\s*=\s*"([^"]+)"') {
        $resourceGroupName = $matches[1]
        Write-Host "Using resource group name from terraform.tfvars: $resourceGroupName" -ForegroundColor Green
    } else {
        $resourceGroupName = Read-Host "Enter resource group name (will be created if it doesn't exist)"
    }
} else {
    $resourceGroupName = Read-Host "Enter resource group name (will be created if it doesn't exist)"
}

$resourceGroupExists = az group exists -n $resourceGroupName | ConvertFrom-Json

if (-not $resourceGroupExists) {
    Write-Host "Creating resource group $resourceGroupName in $location..." -ForegroundColor Yellow
    az group create --name $resourceGroupName --location $location | Out-Null
    Write-Host "Resource group created" -ForegroundColor Green
} else {
    Write-Host "Using existing resource group $resourceGroupName" -ForegroundColor Green
}

#############################################################
# Infrastructure Deployment (Terraform)
#############################################################

Write-Host "`n
#########################################################
# Infrastructure Deployment with Terraform
#########################################################
" -ForegroundColor Cyan

# Update subscription_id in the terraform.tfvars if needed
if (Test-Path $tfVarsPath) {
    Write-Host "Using existing terraform.tfvars file at $tfVarsPath" -ForegroundColor Green
    
    # We already read the content earlier, no need to read it again if it exists
    if (-not (Get-Variable -Name tfVarsContent -ErrorAction SilentlyContinue)) {
        $tfVarsContent = Get-Content -Path $tfVarsPath -Raw
    }
    
    if (-not ($tfVarsContent -match 'subscription_id\s*=')) {
        Write-Host "Adding subscription_id to terraform.tfvars..." -ForegroundColor Yellow
        $tfVarsContent += "`nsubscription_id = `"$($subscription.id)`"`n"
        Set-Content -Path $tfVarsPath -Value $tfVarsContent
        Write-Host "Updated terraform.tfvars with subscription_id" -ForegroundColor Green
    }
} else {
    Write-Host "No terraform.tfvars file found. Please create one in the infra directory." -ForegroundColor Red
    exit 1
}

# Navigate to infrastructure directory
Set-Location -Path $infraDir

# Initialize Terraform
Write-Host "Initializing Terraform..." -ForegroundColor Yellow
terraform init

# Create an execution plan
Write-Host "`nCreating Terraform execution plan..." -ForegroundColor Yellow
terraform plan -out=tfplan

# Ask user if they want to apply the plan
$applyTerraform = Read-Host "`nDo you want to apply the Terraform plan? (y/n)"
if ($applyTerraform -ne "y") {
    Write-Host "Terraform apply skipped. Exiting." -ForegroundColor Yellow
    exit 0
}

# Apply the plan
Write-Host "`nApplying Terraform plan..." -ForegroundColor Yellow
terraform apply -auto-approve tfplan

Write-Host "`nInfrastructure deployment completed" -ForegroundColor Green

# Get the outputs
$acrName = terraform output -raw acr_name
$acrLoginServer = "$acrName.azurecr.io"
$aksClusterName = terraform output -raw aks_cluster_name
$aksResourceGroup = terraform output -raw aks_resource_group_name

#############################################################
# Application Deployment (Docker)
#############################################################

Write-Host "`n
#########################################################
# Application Deployment with Docker
#########################################################
" -ForegroundColor Cyan

# Navigate to application directory
$appDir = Join-Path -Path $rootDir -ChildPath "application"
Set-Location -Path $appDir

# Login to Azure Container Registry
Write-Host "Logging in to Azure Container Registry..." -ForegroundColor Yellow
az acr login --name $acrName

# Build and push the Docker image
$imageTag = "$acrLoginServer/demo-app:v1"
Write-Host "Building Docker image..." -ForegroundColor Yellow
docker build -t $imageTag .

Write-Host "Pushing Docker image to ACR..." -ForegroundColor Yellow
docker push $imageTag

Write-Host "`nDocker image pushed to ACR" -ForegroundColor Green

#############################################################
# Configure kubectl to use AKS cluster
#############################################################

Write-Host "`n
#########################################################
# Configuring kubectl to use AKS cluster
#########################################################
" -ForegroundColor Cyan

Write-Host "Getting AKS credentials..." -ForegroundColor Yellow
az aks get-credentials --resource-group $aksResourceGroup --name $aksClusterName --overwrite-existing

#############################################################
# Deploy with Helm
#############################################################

Write-Host "`n
#########################################################
# Deploying to AKS with Helm
#########################################################
" -ForegroundColor Cyan

# Navigate to helm-chart directory
$helmDir = Join-Path -Path $rootDir -ChildPath "helm-chart"
Set-Location -Path $helmDir

# Update values.yaml file
$valuesFilePath = Join-Path -Path $helmDir -ChildPath "values.yaml"
$valuesContent = Get-Content -Path $valuesFilePath -Raw
$valuesContent = $valuesContent -replace 'repository: ankitdemoacr\.azurecr\.io/demo-app', "repository: $acrLoginServer/demo-app"
$valuesContent = $valuesContent -replace 'tag: "v2"', 'tag: "v1"'
Set-Content -Path $valuesFilePath -Value $valuesContent

Write-Host "Updated Helm values.yaml with ACR login server" -ForegroundColor Yellow

# Create the app namespace if it doesn't exist
Write-Host "Creating 'app' namespace if it doesn't exist..." -ForegroundColor Yellow
$namespaceExists = kubectl get namespace app --ignore-not-found
if (-not $namespaceExists) {
    kubectl create namespace app
    Write-Host "Created 'app' namespace" -ForegroundColor Green
} else {
    Write-Host "Using existing 'app' namespace" -ForegroundColor Green
}

# Install/Upgrade Helm chart
Write-Host "Deploying application with Helm to 'app' namespace..." -ForegroundColor Yellow
helm upgrade --install my-app . --namespace app --create-namespace --wait

Write-Host "`nApplication deployed successfully with Helm" -ForegroundColor Green

# Display application URL information
Write-Host "`n
#########################################################
# Deployment Complete!
#########################################################
" -ForegroundColor Cyan

Write-Host "To check the deployment status, run:" -ForegroundColor Yellow
Write-Host "kubectl get pods -n app" -ForegroundColor White

Write-Host "`nTo get the application URL, run:" -ForegroundColor Yellow
Write-Host "kubectl get ingress -n app" -ForegroundColor White

Write-Host "`nYou can test the app by running:" -ForegroundColor Yellow
Write-Host "curl http://INGRESS_IP" -ForegroundColor White

# Return to the root directory
Set-Location -Path $rootDir