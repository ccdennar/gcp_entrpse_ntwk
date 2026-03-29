# === Project Configuration ===
variable "project_id" {
  description = "GCP Project ID where resources will be created"
  type        = string
}

variable "project_name" {
  description = "Human-readable project name for resource naming"
  type        = string
  default     = "enterprise"
}

variable "environment" {
  description = "Environment identifier (prod, staging, dev, sandbox)"
  type        = string
  validation {
    condition     = contains(["prod", "staging", "dev", "sandbox"], var.environment)
    error_message = "Environment must be one of: prod, staging, dev, sandbox."
  }
}

# === Network Configuration ===
variable "vpc_cidr" {
  description = "Base CIDR range for the entire VPC (e.g., 10.0.0.0/16)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "regions" {
  description = "List of GCP regions for subnet distribution"
  type        = list(string)
  default     = ["us-central1", "us-east1", "europe-west1"]
}

# === Subnet Configuration ===
variable "auto_generate_subnets" {
  description = "Automatically generate subnets from CIDR ranges vs manual definition"
  type        = bool
  default     = false
}

variable "tiers" {
  description = "Application tiers for auto-generated subnet layout"
  type = list(object({
    name                     = string
    purpose                  = string
    newbits                  = optional(number, 8)
    private_ip_google_access = optional(bool, false)
    flow_logs                = optional(bool, true)
  }))
  default = []
}

variable "custom_subnets" {
  description = "Manual subnet definitions when auto_generate_subnets = false"
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
  default = {}
}

# === Security Configuration ===
variable "web_access_cidrs" {
  description = "Allowed CIDRs for web tier access (set to [] for internal only)"
  type        = list(string)
  default     = []
}

variable "admin_cidrs" {
  description = "Allowed CIDRs for administrative/bastion access"
  type        = list(string)
  default     = []
}

variable "app_ports" {
  description = "Application tier exposed ports"
  type        = list(string)
  default     = ["8080", "8443"]
}

variable "db_ports" {
  description = "Database tier exposed ports"
  type        = list(string)
  default     = ["5432", "3306", "27017"]
}

variable "custom_firewall_rules" {
  description = "Additional or overriding firewall rules"
  type = map(object({
    description = string
    direction   = string
    priority    = number
    ranges      = list(string)
    allow = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })), [])
    deny = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })), [])
    target_tags             = optional(list(string), [])
    source_tags             = optional(list(string), [])
    source_service_accounts = optional(list(string), [])
    target_service_accounts = optional(list(string), [])
  }))
  default = {}
}

variable "disabled_default_rules" {
  description = "List of default GCP firewall rules to disable"
  type        = list(string)
  default     = ["default-allow-internal", "default-allow-ssh", "default-allow-rdp", "default-allow-icmp"]
}

# === NAT Configuration ===
variable "enable_nat" {
  description = "Enable Cloud NAT for private instance egress"
  type        = bool
  default     = true
}

variable "nat_regions" {
  description = "Regions where Cloud NAT should be deployed"
  type        = list(string)
  default     = []
}

variable "nat_subnet_mapping" {
  description = "Map of region to subnet name for NAT placement"
  type        = map(string)
  default     = {}
}

variable "nat_config" {
  description = "Cloud NAT configuration parameters"
  type = object({
    min_ports_per_vm               = optional(number, 64)
    max_ports_per_vm               = optional(number, 1024)
    enable_dynamic_port_allocation = optional(bool, true)
    log_filter                     = optional(string, "ERRORS_ONLY")
  })
  default = {}
}

# === Observability ===
variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs globally"
  type        = bool
  default     = true
}

variable "flow_logs_config" {
  description = "VPC Flow Logs configuration"
  type = object({
    aggregation_interval = optional(string, "INTERVAL_5_SEC")
    flow_sampling        = optional(number, 0.5)
    metadata             = optional(string, "INCLUDE_ALL_METADATA")
  })
  default = {}
}

# === Routing ===
variable "routing_mode" {
  description = "VPC routing mode (REGIONAL or GLOBAL)"
  type        = string
  default     = "GLOBAL"
}

variable "delete_default_routes" {
  description = "Remove default internet route for security hardening"
  type        = bool
  default     = true
}

variable "enable_private_service_access" {
  description = "Enable private service access for managed services"
  type        = bool
  default     = true
}

variable "private_service_cidr_prefix" {
  description = "Prefix length for private service access range"
  type        = number
  default     = 16
}

variable "create_deny_all_rules" {
  description = "Create explicit deny-all firewall rules"
  type        = bool
  default     = true
}