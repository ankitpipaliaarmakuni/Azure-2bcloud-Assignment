resource "azurerm_virtual_network" "vnet" {
  name                = coalesce(var.virtual_network_name, "${var.tags.project}-${var.tags.environment}-vnet")
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
  dns_servers         = var.dns_servers

  # Optional advanced configurations
  bgp_community                  = var.bgp_community
  edge_zone                      = var.edge_zone
  flow_timeout_in_minutes        = var.flow_timeout_in_minutes
  private_endpoint_vnet_policies = var.private_endpoint_vnet_policies

  # DDoS Protection Plan
  dynamic "ddos_protection_plan" {
    for_each = var.ddos_protection_plan != null ? [var.ddos_protection_plan] : []
    content {
      id     = ddos_protection_plan.value.id
      enable = ddos_protection_plan.value.enable
    }
  }

  # Encryption
  dynamic "encryption" {
    for_each = var.encryption != null ? [var.encryption] : []
    content {
      enforcement = encryption.value.enforcement
    }
  }

  # IP Address Pool
  dynamic "ip_address_pool" {
    for_each = var.ip_address_pools
    content {
      id                     = ip_address_pool.value.id
      number_of_ip_addresses = ip_address_pool.value.number_of_ip_addresses
    }
  }

  # Inline Subnets (use this approach instead of separate resources)
  dynamic "subnet" {
    for_each = var.use_inline_subnets ? { for s in var.subnets : s.name => s } : {}
    content {
      name                                      = subnet.value.name
      address_prefixes                          = [subnet.value.address_prefix]
      security_group                            = subnet.value.security_group_id
      default_outbound_access_enabled           = subnet.value.default_outbound_access_enabled
      private_endpoint_network_policies         = subnet.value.private_endpoint_network_policies
      private_link_service_network_policies_enabled = subnet.value.private_link_service_network_policies_enabled
      route_table_id                            = subnet.value.route_table_id
      service_endpoints                         = subnet.value.service_endpoints
      service_endpoint_policy_ids               = subnet.value.service_endpoint_policy_ids

      dynamic "delegation" {
        for_each = subnet.value.delegation != null ? [subnet.value.delegation] : []
        content {
          name = delegation.value.name
          service_delegation {
            name    = delegation.value.service_name
            actions = delegation.value.actions
          }
        }
      }
    }
  }

  tags = merge(
    {
      "Environment" = var.tags.environment,
      "Project"     = var.tags.project
    },
    var.extra_tags
  )
}

# Standalone Subnet Resources (use when use_inline_subnets = false)
resource "azurerm_subnet" "subnets" {
  for_each             = var.use_inline_subnets ? {} : { for s in var.subnets : s.name => s }
  name                 = each.value.name
  resource_group_name  = azurerm_virtual_network.vnet.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [each.value.address_prefix]
  
  default_outbound_access_enabled           = each.value.default_outbound_access_enabled
  private_endpoint_network_policies         = each.value.private_endpoint_network_policies
  private_link_service_network_policies_enabled = each.value.private_link_service_network_policies_enabled
  service_endpoints                         = each.value.service_endpoints
  service_endpoint_policy_ids               = each.value.service_endpoint_policy_ids

  dynamic "delegation" {
    for_each = each.value.delegation != null ? [each.value.delegation] : []
    content {
      name = delegation.value.name
      service_delegation {
        name    = delegation.value.service_name
        actions = delegation.value.actions
      }
    }
  }

  depends_on = [azurerm_virtual_network.vnet]
}

# Associate Network Security Groups (only for standalone subnets)
resource "azurerm_subnet_network_security_group_association" "nsg" {
  for_each = var.use_inline_subnets ? {} : {
    for k, v in var.subnets : k => v if v.security_group_id != null
  }

  subnet_id                 = azurerm_subnet.subnets[each.value.name].id
  network_security_group_id = each.value.security_group_id
}

# Associate Route Tables (only for standalone subnets)
resource "azurerm_subnet_route_table_association" "rt" {
  for_each = var.use_inline_subnets ? {} : {
    for k, v in var.subnets : k => v if v.route_table_id != null
  }

  subnet_id      = azurerm_subnet.subnets[each.value.name].id
  route_table_id = each.value.route_table_id
}