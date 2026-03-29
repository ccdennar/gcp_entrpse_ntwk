terraform {
  required_version = ">= 1.5"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = local.primary_region
}

provider "google-beta" {
  project = var.project_id
  region  = local.primary_region
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  name_prefix                   = local.name_prefix
  vpc_cidr                      = var.vpc_cidr
  routing_mode                  = var.routing_mode
  delete_default_routes         = var.delete_default_routes
  subnets                       = local.final_subnets 
  enable_flow_logs              = var.enable_flow_logs
  flow_logs_config              = var.flow_logs_config
  enable_private_service_access = var.enable_private_service_access
  private_service_cidr_prefix   = var.private_service_cidr_prefix
}

# Firewall Module
module "firewall" {
  source = "./modules/firewall"

  network_name           = module.vpc.network_name
  network_self_link      = module.vpc.network_self_link
  firewall_rules         = local.firewall_rules
  disabled_default_rules = var.disabled_default_rules
  create_deny_all_rules  = var.create_deny_all_rules
}

# Cloud NAT Module - uses for_each on set
module "cloud_nat" {
  source   = "./modules/cloud_nat"
  for_each = local.nat_enabled

  region       = each.value
  network_name = module.vpc.network_name
  router_name  = "${local.name_prefix}-router-${each.value}"
  nat_name     = "${local.name_prefix}-nat-${each.value}"
  
  
  min_ports_per_vm               = var.nat_config.min_ports_per_vm
  max_ports_per_vm               = var.nat_config.max_ports_per_vm
  enable_dynamic_port_allocation = var.nat_config.enable_dynamic_port_allocation
  log_filter                     = var.nat_config.log_filter
}
