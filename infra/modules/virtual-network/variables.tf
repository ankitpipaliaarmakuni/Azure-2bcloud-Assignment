variable "virtual_network_name" {
  description = "The name of the virtual network. If not provided, will be generated from project and environment tags."
  type        = string
  default     = null
}

variable "resource_group_name" {
  description = "The name of the resource group in which to create the virtual network."
  type        = string
}

variable "location" {
  description = "The location/region where the virtual network is created."
  type        = string
}

variable "address_space" {
  description = "The address space that is used by the virtual network. You can supply more than one address space."
  type        = list(string)
  default     = null
}

variable "dns_servers" {
  description = "List of IP addresses of DNS servers. Set to [] to remove DNS servers."
  type        = list(string)
  default     = []
}

variable "bgp_community" {
  description = "The BGP community attribute in format <as-number>:<community-value>."
  type        = string
  default     = null
}

variable "edge_zone" {
  description = "Specifies the Edge Zone within the Azure Region where this Virtual Network should exist."
  type        = string
  default     = null
}

variable "flow_timeout_in_minutes" {
  description = "The flow timeout in minutes for the Virtual Network (between 4 and 30)."
  type        = number
  default     = null

  validation {
    condition     = var.flow_timeout_in_minutes == null || (var.flow_timeout_in_minutes >= 4 && var.flow_timeout_in_minutes <= 30)
    error_message = "Flow timeout must be between 4 and 30 minutes."
  }
}

variable "private_endpoint_vnet_policies" {
  description = "The Private Endpoint VNet Policies. Possible values: Disabled, Basic."
  type        = string
  default     = "Disabled"

  validation {
    condition     = contains(["Disabled", "Basic"], var.private_endpoint_vnet_policies)
    error_message = "Private endpoint VNet policies must be either 'Disabled' or 'Basic'."
  }
}

variable "ddos_protection_plan" {
  description = "DDoS Protection Plan configuration."
  type = object({
    id     = string
    enable = bool
  })
  default = null
}

variable "encryption" {
  description = "Encryption configuration for the Virtual Network."
  type = object({
    enforcement = string
  })
  default = null

  validation {
    condition     = var.encryption == null || contains(["AllowUnencrypted", "DropUnencrypted"], var.encryption.enforcement)
    error_message = "Encryption enforcement must be either 'AllowUnencrypted' or 'DropUnencrypted'."
  }
}

variable "ip_address_pools" {
  description = "List of IP address pools (IPAM). Maximum of 2 (one IPv4 and one IPv6)."
  type = list(object({
    id                     = string
    number_of_ip_addresses = string
  }))
  default = []

  validation {
    condition     = length(var.ip_address_pools) <= 2
    error_message = "Maximum of 2 IP address pools allowed (one IPv4 and one IPv6)."
  }
}

variable "use_inline_subnets" {
  description = "Whether to use inline subnets (true) or standalone subnet resources (false). Cannot mix both approaches."
  type        = bool
  default     = false
}

variable "subnets" {
  description = "List of subnets to create within the virtual network."
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

  validation {
    condition = alltrue([
      for s in var.subnets : contains(
        ["Disabled", "Enabled", "NetworkSecurityGroupEnabled", "RouteTableEnabled"],
        s.private_endpoint_network_policies
      )
    ])
    error_message = "Private endpoint network policies must be one of: Disabled, Enabled, NetworkSecurityGroupEnabled, RouteTableEnabled."
  }
}

variable "tags" {
  description = "Required tags for the virtual network."
  type = object({
    environment = string
    project     = string
  })
}

variable "extra_tags" {
  description = "Additional tags to assign to the resource."
  type        = map(string)
  default     = {}
}