variable "region" {
  type = string
}

variable "network_name" {
  type = string
}

variable "router_name" {
  type = string
}

variable "nat_name" {
  type = string
}

variable "subnet_name" {
  type    = string
  default = null
}

variable "min_ports_per_vm" {
  type    = number
  default = 64
}

variable "max_ports_per_vm" {
  type    = number
  default = 1024
}

variable "enable_dynamic_port_allocation" {
  type    = bool
  default = true
}

variable "log_filter" {
  type    = string
  default = "ERRORS_ONLY"
}

variable "bgp_asn" {
  type    = number
  default = 64514
}