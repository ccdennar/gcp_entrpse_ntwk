output "router_name" {
  description = "Name of the Cloud Router"
  value       = google_compute_router.router.name
}

output "router_id" {
  description = "ID of the Cloud Router"
  value       = google_compute_router.router.id
}

output "nat_name" {
  description = "Name of the NAT gateway"
  value       = google_compute_router_nat.nat.name
}

output "nat_id" {
  description = "ID of the NAT gateway"
  value       = google_compute_router_nat.nat.id
}

output "nat_ips" {
  description = "List of NAT IP addresses allocated"
  value       = google_compute_router_nat.nat.nat_ips
}

output "region" {
  description = "Region where NAT is deployed"
  value       = var.region
}

output "subnet_mapping" {
  description = "Subnet configuration for this NAT"
  value       = var.subnet_name != null ? {
    mode   = "LIST_OF_SUBNETWORKS"
    subnet = var.subnet_name
  } : {
    mode   = "ALL_SUBNETWORKS_ALL_IP_RANGES"
    subnet = null
  }
}