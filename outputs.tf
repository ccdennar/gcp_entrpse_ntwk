# VPC Outputs
output "vpc" {
  description = "VPC network details"
  value = {
    name       = module.vpc.network_name
    id         = module.vpc.network_id
    self_link  = module.vpc.network_self_link
    cidr       = var.vpc_cidr
  }
}

output "subnets" {
  description = "Map of all subnets by key"
  value       = module.vpc.subnets
}

output "subnet_ids" {
  description = "List of subnet IDs for easy reference"
  value       = [for s in module.vpc.subnets : s.id]
}

output "subnet_regions" {
  description = "Map of subnet names to regions"
  value       = {for k, v in module.vpc.subnets : k => v.region}
}

# Firewall Outputs
output "firewall_rules" {
  description = "Map of created firewall rules"
  value       = module.firewall.firewall_rules
}

# NAT Outputs
output "nat" {
  description = "Cloud NAT configuration by region"
  value       = {
    for region, mod in module.cloud_nat : region => {
      router_name = mod.router_name
      nat_name    = mod.nat_name
      nat_ips     = mod.nat_ips
    }
  }
}

output "nat_regions" {
  description = "Regions where NAT is enabled"
  value       = keys(module.cloud_nat)
}

# Security Outputs
output "security_summary" {
  description = "Security configuration summary"
  value = {
    deny_all_rules_enabled = var.create_deny_all_rules
    private_service_access = var.enable_private_service_access
    flow_logs_enabled      = var.enable_flow_logs
    nat_enabled            = var.enable_nat
    nat_regions            = var.nat_regions
  }
  sensitive = false
}