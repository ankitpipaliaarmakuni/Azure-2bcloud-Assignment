output "virtual_network_id" {
  description = "The ID of the Virtual Network."
  value       = azurerm_virtual_network.vnet.id
}

output "virtual_network_name" {
  description = "The name of the Virtual Network."
  value       = azurerm_virtual_network.vnet.name
}

output "virtual_network_guid" {
  description = "The GUID of the Virtual Network."
  value       = azurerm_virtual_network.vnet.guid
}

output "virtual_network_location" {
  description = "The location of the Virtual Network."
  value       = azurerm_virtual_network.vnet.location
}

output "virtual_network_address_space" {
  description = "The address space of the Virtual Network."
  value       = azurerm_virtual_network.vnet.address_space
}

output "virtual_network_dns_servers" {
  description = "The DNS servers of the Virtual Network."
  value       = azurerm_virtual_network.vnet.dns_servers
}

output "virtual_network_subnets" {
  description = "Blocks containing configuration of each subnet (from inline subnets)."
  value       = azurerm_virtual_network.vnet.subnet
}

output "ip_address_pool_allocated_prefixes" {
  description = "The list of IP address prefixes allocated to the Virtual Network from IP address pools."
  value = [
    for pool in azurerm_virtual_network.vnet.ip_address_pool :
    pool.allocated_ip_address_prefixes
  ]
}

output "subnet_ids" {
  description = "Map of subnet names to their IDs (from standalone subnets)."
  value = var.use_inline_subnets ? {
    for subnet in azurerm_virtual_network.vnet.subnet :
    subnet.name => subnet.id
  } : {
    for k, v in azurerm_subnet.subnets :
    v.name => v.id
  }
}

output "subnet_address_prefixes" {
  description = "Map of subnet names to their address prefixes."
  value = var.use_inline_subnets ? {
    for subnet in azurerm_virtual_network.vnet.subnet :
    subnet.name => subnet.address_prefixes
  } : {
    for k, v in azurerm_subnet.subnets :
    v.name => v.address_prefixes
  }
}

output "resource_group_name" {
  description = "The name of the resource group."
  value       = azurerm_virtual_network.vnet.resource_group_name
}

output "tags" {
  description = "The tags assigned to the Virtual Network."
  value       = azurerm_virtual_network.vnet.tags
}