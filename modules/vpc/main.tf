resource "google_compute_network" "vpc" {
  name                            = "${var.name_prefix}-vpc"
  auto_create_subnetworks         = false
  routing_mode                    = var.routing_mode
  delete_default_routes_on_create = var.delete_default_routes
  
  description = "Managed by Terraform - ${var.name_prefix}"
}

resource "google_compute_subnetwork" "subnets" {
  for_each = var.subnets

  name                     = "${var.name_prefix}-subnet-${each.value.name}-${each.value.region}"
  region                   = each.value.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = each.value.ip_cidr_range
  private_ip_google_access = lookup(each.value, "private_ip_google_access", false)

  dynamic "log_config" {
    for_each = var.enable_flow_logs && lookup(each.value, "flow_logs", true) ? { enabled = true } : {}
    content {
      aggregation_interval = var.flow_logs_config.aggregation_interval
      flow_sampling        = var.flow_logs_config.flow_sampling
      metadata             = var.flow_logs_config.metadata
    }
  }

  dynamic "secondary_ip_range" {
    for_each = lookup(each.value, "secondary_ip_ranges", {})
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }

  
}

# Private Service Access - conditional via empty map
resource "google_compute_global_address" "private_service_access" {
  for_each = var.enable_private_service_access ? { enabled = true } : {}

  name          = "${var.name_prefix}-private-service-access"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.private_service_cidr_prefix
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  for_each = var.enable_private_service_access ? { enabled = true } : {}

  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_access["enabled"].name]
}
