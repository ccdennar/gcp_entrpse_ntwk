
output "network_name" {
  value = google_compute_network.vpc.name
}

output "network_id" {
  value = google_compute_network.vpc.id
}

output "network_self_link" {
  value = google_compute_network.vpc.self_link
}

output "subnets" {
  value = {
    for key, subnet in google_compute_subnetwork.subnets : key => {
      id                       = subnet.id
      name                     = subnet.name
      self_link                = subnet.self_link
      region                   = subnet.region
      ip_cidr_range            = subnet.ip_cidr_range
      gateway_address          = subnet.gateway_address
      private_ip_google_access = subnet.private_ip_google_access
      purpose                  = var.subnets[key].purpose  # FIXED: Use input var instead of labels
      secondary_ip_ranges      = {
        for range in subnet.secondary_ip_range : range.range_name => range.ip_cidr_range
      }
    }
  }
}

output "private_service_access" {
  value = var.enable_private_service_access ? {
    address_name  = google_compute_global_address.private_service_access["enabled"].name
    address       = google_compute_global_address.private_service_access["enabled"].address
    prefix_length = google_compute_global_address.private_service_access["enabled"].prefix_length
  } : null
}
