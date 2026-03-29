variable "name_prefix" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "routing_mode" {
  type    = string
  default = "GLOBAL"
}

variable "delete_default_routes" {
  type    = bool
  default = true
}

variable "subnets" {
  type = map(object({
    name                     = string
    region                   = string
    purpose                  = string
    ip_cidr_range           = string
    private_ip_google_access = optional(bool, false)
    flow_logs                = optional(bool, true)
    secondary_ip_ranges      = optional(map(object({
      range_name    = string
      ip_cidr_range = string
    })), {})
  }))
}

variable "enable_flow_logs" {
  type    = bool
  default = true
}

variable "flow_logs_config" {
  type = object({
    aggregation_interval = string
    flow_sampling        = number
    metadata             = string
  })
  default = {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

variable "enable_private_service_access" {
  type    = bool
  default = false
}

variable "private_service_cidr_prefix" {
  type    = number
  default = 16
}