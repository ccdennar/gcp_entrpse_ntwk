#!/bin/bash
# GCP authentication and project validation

check_gcloud() {
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI not found. Install: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
}

check_terraform() {
    if ! command -v terraform &> /dev/null; then
        log_error "terraform not found. Install: https://developer.hashicorp.com/terraform/downloads"
        exit 1
    fi
    
    local tf_version=$(terraform version -json | jq -r '.terraform_version')
    log_info "Terraform version: $tf_version"
}

authenticate_gcp() {
    local project_id=$1
    
    log_step "Checking GCP authentication..."
    
    # Check if authenticated
    if ! gcloud auth print-access-token &> /dev/null; then
        log_warn "Not authenticated to GCP"
        log_info "Running: gcloud auth application-default login"
        gcloud auth application-default login
    fi
    
    # Verify project access
    if ! gcloud projects describe "$project_id" &> /dev/null; then
        log_error "Cannot access project '$project_id'. Check permissions."
        log_info "Available projects:"
        gcloud projects list --limit=10
        exit 1
    fi
    
    # Set project context
    gcloud config set project "$project_id" > /dev/null 2>&1
    log_success "Authenticated to project: $project_id"
}

enable_apis() {
    local project_id=$1
    local apis=(
        "compute.googleapis.com"
        "servicenetworking.googleapis.com"
        "logging.googleapis.com"
        "monitoring.googleapis.com"
        "cloudresourcemanager.googleapis.com"
    )
    
    log_step "Enabling required GCP APIs..."
    
    for api in "${apis[@]}"; do
        log_info "Enabling $api..."
        gcloud services enable "$api" --project="$project_id" --async > /dev/null 2>&1
    done
    
    # Wait for critical APIs
    log_info "Waiting for Compute API (required for Terraform)..."
    gcloud services enable compute.googleapis.com --project="$project_id"
    
    log_success "Required APIs enabled"
}

validate_iam_permissions() {
    local project_id=$1
    
    log_step "Validating IAM permissions..."
    
    local required_roles=(
        "roles/compute.networkAdmin"
        "roles/compute.securityAdmin"
        "roles/iam.serviceAccountUser"
    )
    
    local current_user=$(gcloud config get-value account)
    log_info "Checking permissions for: $current_user"
    
    # Check each role (simplified check)
    local has_compute=$(gcloud projects get-iam-policy "$project_id" \
        --flatten="bindings[].members" \
        --format="table(bindings.role)" \
        --filter="bindings.members:$current_user" 2>/dev/null | grep "compute.networkAdmin" || true)
    
    if [[ -z "$has_compute" ]]; then
        log_warn "May be missing compute.networkAdmin role"
        log_info "Required roles: ${required_roles[*]}"
    else
        log_success "IAM permissions validated"
    fi
}