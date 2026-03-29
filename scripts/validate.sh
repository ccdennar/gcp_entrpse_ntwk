#!/bin/bash
# Comprehensive validation before deployment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/colors.sh"

log_header "Pre-Deployment Validation"

cd "$PROJECT_ROOT"

# Check required files
log_step "Checking required files..."

required_files=(
    "main.tf"
    "variables.tf"
    "versions.tf"
    "modules/vpc/main.tf"
    "modules/firewall/main.tf"
    "modules/cloud_nat/main.tf"
)

for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        log_success "Found: $file"
    else
        log_error "Missing: $file"
        exit 1
    fi
done

# Terraform validation
log_step "Running terraform validate..."

terraform init -backend=false > /dev/null 2>&1
if terraform validate; then
    log_success "Terraform configuration is valid"
else
    log_error "Terraform validation failed"
    exit 1
fi

# Check formatting
log_step "Checking terraform formatting..."

if terraform fmt -check -recursive; then
    log_success "All files properly formatted"
else
    log_warn "Some files need formatting. Run: terraform fmt -recursive"
fi

# TFLint (if installed)
if command -v tflint &> /dev/null; then
    log_step "Running tflint..."
    tflint --recursive || log_warn "TFLint found issues"
else
    log_info "TFLint not installed (optional)"
fi

# Checkov (if installed)
if command -v checkov &> /dev/null; then
    log_step "Running Checkov security scan..."
    checkov --directory . --framework terraform --quiet || log_warn "Checkov found issues"
else
    log_info "Checkov not installed (optional)"
fi

# Validate tfvars
log_step "Validating terraform.tfvars..."

if [[ -f "terraform.tfvars" ]]; then
    # Check for required variables
    required_vars=("project_id" "environment" "regions")
    for var in "${required_vars[@]}"; do
        if grep -q "^$var" terraform.tfvars; then
            log_success "Found required var: $var"
        else
            log_warn "Missing recommended var: $var"
        fi
    done
    
    # Security checks
    if grep -q '0\.0\.0\.0/0' terraform.tfvars; then
        log_warn "Found 0.0.0.0/0 in terraform.tfvars - ensure this is intentional"
    fi
else
    log_warn "No terraform.tfvars found"
fi

log_success "Validation completed!"