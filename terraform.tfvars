# Production Example
project_id    = "1097684345446"
project_name  = "fresh-84"
environment   = "dev"

# Network
vpc_cidr      = "10.0.0.0/16"
regions       = ["us-central1", "us-east1", "europe-west1"]

# Subnets - Auto-generate from tiers
auto_generate_subnets = true
tiers = [
  { 
    name = "web", 
    purpose = "WEB_SERVERS", 
    private_ip_google_access = false,
    flow_logs = true
  },
  { 
    name = "api", 
    purpose = "API_SERVERS", 
    private_ip_google_access = false,
    flow_logs = true
  },
  { 
    name = "cache", 
    purpose = "REDIS_CLUSTER", 
    private_ip_google_access = true,
    flow_logs = true
  },
  { 
    name = "db", 
    purpose = "CLOUD_SQL", 
    private_ip_google_access = true,
    flow_logs = true
  },
  { 
    name = "mgmt", 
    purpose = "BASTION", 
    private_ip_google_access = false,
    flow_logs = true
  }
]

# Security
web_access_cidrs = ["203.0.113.0/24", "198.51.100.0/24"]  # Office + VPN
admin_cidrs      = ["203.0.113.10/32"]                     # Jump host only
app_ports        = ["8080", "9090"]                        # Custom app ports
db_ports         = ["5432", "6379"]                        # PostgreSQL + Redis

# Custom firewall rule override
custom_firewall_rules = {
  "allow-monitoring" = {
    description = "Allow Prometheus/Grafana scraping"
    direction   = "INGRESS"
    priority    = 950
    ranges      = ["10.0.5.0/24"]  # Monitoring subnet
    allow = [{ protocol = "tcp", ports = ["9090", "3000"] }]
    target_tags = ["monitored"]
  }
}

enable_nat = true
nat_regions = ["us-central1", "us-east1"]  # mgmt only exists here
nat_subnet_mapping = {} 

nat_config = {
  min_ports_per_vm = 128
  log_filter       = "ALL"
}
