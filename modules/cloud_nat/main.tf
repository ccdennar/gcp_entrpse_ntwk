resource "google_compute_router" "router" {
  name    = var.router_name
  region  = var.region
  network = var.network_name

  bgp {
    asn = var.bgp_asn
  }
}

resource "google_compute_router_nat" "nat" {
  name                               = var.nat_name
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  min_ports_per_vm = var.min_ports_per_vm
  max_ports_per_vm = var.max_ports_per_vm
  
  enable_dynamic_port_allocation = var.enable_dynamic_port_allocation

  log_config {
    enable = true
    filter = var.log_filter
  }
}
