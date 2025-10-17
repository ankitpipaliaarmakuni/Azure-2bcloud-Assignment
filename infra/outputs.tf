output "acr_name" {
  description = "The name of the Azure Container Registry"
  value       = azurerm_container_registry.acr.name
}

output "aks_cluster_name" {
  description = "The name of the AKS cluster"
  value       = module.aks.aks_name
}

output "aks_resource_group_name" {
  description = "The resource group name of the AKS cluster"
  value       = data.azurerm_resource_group.rg.name
}

output "vnet_name" {
  description = "The name of the Virtual Network"
  value       = azurerm_virtual_network.vnet.name
}