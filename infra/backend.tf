terraform {
  backend "azurerm" {
    resource_group_name  = "Ankit-Pipalia-Candidate"
    storage_account_name = "ankitterraformassignment"
    container_name       = "terraform-state"
    key                  = "terraform.tfstate"
  }
}