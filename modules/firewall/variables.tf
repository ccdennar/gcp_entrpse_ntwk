variable "network_name" {
  type = string
}

variable "network_self_link" {
  type = string
}

variable "firewall_rules" {
  type = map(object({
    description             = string
    direction               = string
    priority                = number
    ranges                  = list(string)
    allow                   = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })), [])
    deny                    = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })), [])
    target_tags             = optional(list(string), [])
    source_tags             = optional(list(string), [])
    source_service_accounts = optional(list(string), [])
    target_service_accounts = optional(list(string), [])
  }))
}

variable "disabled_default_rules" {
  type    = list(string)
  default = []
}

variable "create_deny_all_rules" {
  type    = bool
  default = true
}