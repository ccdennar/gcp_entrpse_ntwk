
locals {
  name_prefix    = "${var.environment}-${var.project_name}"
  primary_region = var.regions[0]
  
  generated_subnets = var.auto_generate_subnets ? {
    for idx, tier in var.tiers : "${tier.name}-${var.regions[idx % length(var.regions)]}" => {
      name                     = tier.name
      region                   = var.regions[idx % length(var.regions)]
      purpose                  = tier.purpose
      ip_cidr_range           = cidrsubnet(var.vpc_cidr, lookup(tier, "newbits", 8), idx)
      private_ip_google_access = lookup(tier, "private_ip_google_access", false)
      flow_logs                = lookup(tier, "flow_logs", true)
      secondary_ip_ranges      = {}
    }
  } : {}
  
  final_subnets = var.auto_generate_subnets ? local.generated_subnets : var.custom_subnets
  
  nat_enabled = var.enable_nat ? toset(var.nat_regions) : toset([])
  
  firewall_rules = merge(
    {
      internal = {
        description = "Allow internal VPC traffic"
        direction   = "INGRESS"
        priority    = 1000
        ranges      = [var.vpc_cidr]
        allow       = [{ protocol = "tcp" }, { protocol = "udp" }, { protocol = "icmp" }]
        target_tags = []
        source_tags = []
      }
    },
    length(var.web_access_cidrs) > 0 ? {
      web = {
        description = "Allow HTTP/HTTPS to web tier"
        direction   = "INGRESS"
        priority    = 1000
        ranges      = var.web_access_cidrs
        allow       = [{ protocol = "tcp", ports = ["80", "443"] }]
        target_tags = ["web-tier"]
      }
    } : {},
    length(var.admin_cidrs) > 0 ? {
      bastion = {
        description = "Allow SSH to bastion hosts"
        direction   = "INGRESS"
        priority    = 1000
        ranges      = var.admin_cidrs
        allow       = [{ protocol = "tcp", ports = ["22"] }]
        target_tags = ["bastion"]
      }
    } : {},
    {
      iap = {
        description = "Allow IAP tunneling"
        direction   = "INGRESS"
        priority    = 900
        ranges      = ["35.235.240.0/20"]
        allow       = [{ protocol = "tcp", ports = ["22", "3389"] }]
        target_tags = ["iap-enabled"]
      }
      app = {
        description = "Allow app tier access from web tier"
        direction   = "INGRESS"
        priority    = 1000
        ranges      = []
        allow       = [{ protocol = "tcp", ports = var.app_ports }]
        target_tags = ["app-tier"]
        source_tags = ["web-tier"]
      }
      database = {
        description = "Allow database access from app tier"
        direction   = "INGRESS"
        priority    = 1000
        ranges      = []
        allow       = [{ protocol = "tcp", ports = var.db_ports }]
        target_tags = ["db-tier"]
        source_tags = ["app-tier"]
      }
    },
    var.custom_firewall_rules
  )
}
