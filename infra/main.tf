data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

module "vnet" {
  source = "./modules/virtual-network"

  virtual_network_name = var.vnet_name
  resource_group_name  = data.azurerm_resource_group.rg.name
  location             = data.azurerm_resource_group.rg.location
  address_space        = var.vnet_address_space
  use_inline_subnets   = var.use_inline_vnet_subnets
  subnets              = var.vnet_subnets
  tags                 = var.tags
}

resource "azurerm_container_registry" "acr" {
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  name                = var.acr_name
  sku                 = var.acr_sku
  tags                = var.tags
}

module "aks" {
  source  = "Azure/aks/azurerm"
  version = "11.0.0"

  prefix                    = var.aks_prefix
  resource_group_name       = data.azurerm_resource_group.rg.name
  location                  = data.azurerm_resource_group.rg.location
  kubernetes_version        = var.kubernetes_version
  automatic_channel_upgrade = var.automatic_channel_upgrade

  attached_acr_id_map = {
    acr = azurerm_container_registry.acr.id
  }

  log_analytics_workspace_enabled = false
  oms_agent_enabled               = false
  rbac_aad_azure_rbac_enabled     = true
  network_plugin                  = var.network_plugin
  network_policy                  = var.network_policy
  os_disk_size_gb                 = var.os_disk_size_gb
  rbac_aad_tenant_id              = data.azurerm_client_config.current.tenant_id
  sku_tier                        = var.aks_sku_tier

  vnet_subnet = {
    id = module.vnet.subnet_ids["aks-subnet"]
  }

  web_app_routing = {
    dns_zone_ids = []
  }

  node_pools = merge(
    {
      workload = {
        name            = "workload"
        vm_size         = "Standard_D2s_v3"
        node_count      = 1
        os_disk_size_gb = var.os_disk_size_gb
        mode            = "User"
        node_labels = {
          "workload-type" = "general"
        }
        vnet_subnet = {
          id = module.vnet.subnet_ids["aks-subnet"]
        }
      }
    }
  )

  tags = var.tags
}