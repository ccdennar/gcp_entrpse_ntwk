resource "google_compute_firewall" "rules" {
  for_each = var.firewall_rules

  name        = "${var.network_name}-${each.key}"
  network     = var.network_name
  description = each.value.description
  direction   = each.value.direction
  priority    = each.value.priority

  source_ranges      = each.value.direction == "INGRESS" ? each.value.ranges : null
  destination_ranges = each.value.direction == "EGRESS" ? each.value.ranges : null
  
  source_tags             = lookup(each.value, "source_tags", [])
  target_tags             = lookup(each.value, "target_tags", [])
  
  dynamic "allow" {
    for_each = lookup(each.value, "allow", [])
    content {
      protocol = allow.value.protocol
      ports    = lookup(allow.value, "ports", null)
    }
  }

  dynamic "deny" {
    for_each = lookup(each.value, "deny", [])
    content {
      protocol = deny.value.protocol
      ports    = lookup(deny.value, "ports", null)
    }
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Deny-all rules using map for conditional creation
resource "google_compute_firewall" "deny_all_ingress" {
  for_each = var.create_deny_all_rules ? { default = true } : {}

  name          = "${var.network_name}-deny-all-ingress"
  network       = var.network_name
  direction     = "INGRESS"
  priority      = 65535
  source_ranges = ["0.0.0.0/0"]

  deny {
    protocol = "all"
  }
}

resource "google_compute_firewall" "deny_all_egress" {
  for_each = var.create_deny_all_rules ? { default = true } : {}

  name               = "${var.network_name}-deny-all-egress"
  network            = var.network_name
  direction          = "EGRESS"
  priority           = 65535
  destination_ranges = ["0.0.0.0/0"]

  deny {
    protocol = "all"
  }
}
