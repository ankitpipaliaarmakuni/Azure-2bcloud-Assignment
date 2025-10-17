terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.48.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id                 = "b99c0710-ded3-407b-b632-9fb5dd7edd13"
  resource_provider_registrations = "none"
}