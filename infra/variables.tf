variable "resource_group_name" {
  description = "Name of the existing resource group"
  type        = string
}

variable "vnet_name" {
  description = "Name of the Virtual Network"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the Virtual Network"
  type        = list(string)
}

variable "vnet_subnets" {
  description = "List of subnets to create within the Virtual Network"
  type = list(object({
    name                                          = string
    address_prefix                                = string
    security_group_id                             = optional(string)
    default_outbound_access_enabled               = optional(bool, true)
    private_endpoint_network_policies             = optional(string, "Disabled")
    private_link_service_network_policies_enabled = optional(bool, true)
    route_table_id                                = optional(string)
    service_endpoints                             = optional(list(string), [])
    service_endpoint_policy_ids                   = optional(list(string), [])
    delegation = optional(object({
      name         = string
      service_name = string
      actions      = optional(list(string))
    }))
  }))
  default = []
}

variable "use_inline_vnet_subnets" {
  description = "Whether to use inline subnet definitions"
  type        = bool
  default     = true
}

variable "acr_name" {
  description = "Name of the Azure Container Registry"
  type        = string
}

variable "acr_sku" {
  description = "SKU of the Azure Container Registry"
  type        = string
}

variable "aks_prefix" {
  description = "Prefix for AKS cluster resources"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
}

variable "automatic_channel_upgrade" {
  description = "The upgrade channel for the AKS cluster"
  type        = string
}

variable "network_plugin" {
  description = "Network plugin for AKS"
  type        = string
}

variable "network_policy" {
  description = "Network policy for AKS"
  type        = string
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
}

variable "aks_sku_tier" {
  description = "SKU tier for AKS cluster"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}
