output "firewall_rules" {
  description = "Map of created firewall rules by name"
  value = {
    for key, rule in google_compute_firewall.rules : key => {
      id          = rule.id
      name        = rule.name
      self_link   = rule.self_link
      direction   = rule.direction
      priority    = rule.priority
      source_ranges = rule.source_ranges
      target_tags   = rule.target_tags
      allow       = [for a in rule.allow : {
        protocol = a.protocol
        ports    = a.ports
      }]
      deny        = [for d in rule.deny : {
        protocol = d.protocol
        ports    = d.ports
      }]
    }
  }
}

output "rule_names" {
  description = "List of all firewall rule names"
  value       = [for r in google_compute_firewall.rules : r.name]
}

output "deny_all_rules" {
  description = "Deny-all rules if created"
  value       = var.create_deny_all_rules ? {
    ingress = {
      id   = google_compute_firewall.deny_all_ingress["default"].id
      name = google_compute_firewall.deny_all_ingress["default"].name
    }
    egress = {
      id   = google_compute_firewall.deny_all_egress["default"].id
      name = google_compute_firewall.deny_all_egress["default"].name
    }
  } : null
}

output "network_name" {
  description = "Network these rules apply to"
  value       = var.network_name
}