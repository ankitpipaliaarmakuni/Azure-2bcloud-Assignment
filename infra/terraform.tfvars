resource_group_name = "Ankit-Pipalia-Candidate"

vnet_name               = "ankit-demo-vnet"
vnet_address_space      = ["10.1.0.0/16"]
use_inline_vnet_subnets = true

vnet_subnets = [
  {
    name           = "aks-subnet"
    address_prefix = "10.1.3.0/24"
  }
]

acr_name = "ankitdemoacr"
acr_sku  = "Basic"

aks_prefix                = "ankit-demo"
kubernetes_version        = "1.33"
automatic_channel_upgrade = "patch"
network_plugin            = "azure"
network_policy            = "azure"
os_disk_size_gb           = 60
aks_sku_tier              = "Standard"

tags = {
  environment = "demo"
  project     = "Assignment"
  owner       = "Ankit Pipalia"
  createdBy   = "Terraform"
}