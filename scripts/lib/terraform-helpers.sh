#!/bin/bash
# Shared Terraform helper functions

init_terraform() {
    local backend_config=${1:-""}
    
    log_step "Initializing Terraform..."
    
    if [[ -n "$backend_config" && -f "$backend_config" ]]; then
        terraform init -backend-config="$backend_config" -reconfigure
    else
        terraform init
    fi
    
    if [[ $? -ne 0 ]]; then
        log_error "Terraform init failed"
        exit 1
    fi
    
    log_success "Terraform initialized"
}

select_workspace() {
    local env=$1
    
    log_step "Selecting workspace: $env"
    
    # Create workspace if doesn't exist
    if ! terraform workspace list | grep -q "$env"; then
        log_info "Creating new workspace: $env"
        terraform workspace new "$env"
    else
        terraform workspace select "$env"
    fi
    
    log_success "Workspace selected: $(terraform workspace show)"
}

generate_backend_config() {
    local env=$1
    local project_id=$2
    local bucket_name="tf-state-${project_id}-${env}"
    local region="us-central1"
    
    log_step "Generating backend configuration..."
    
    # Check if bucket exists, create if not
    if ! gsutil ls "gs://${bucket_name}" &> /dev/null; then
        log_info "Creating GCS bucket: $bucket_name"
        gsutil mb -p "$project_id" -l "$region" "gs://${bucket_name}" 2>/dev/null || true
        gsutil versioning set on "gs://${bucket_name}" 2>/dev/null || true
    fi
    
    cat > "environments/${env}/backend.conf" << EOF
bucket     = "${bucket_name}"
prefix     = "terraform/state"
project    = "${project_id}"
EOF
    
    log_success "Backend config: environments/${env}/backend.conf"
}

run_plan() {
    local plan_file=${1:-"tfplan"}
    local vars_file=${2:-"terraform.tfvars"}
    local extra_args=${3:-""}
    
    log_step "Running Terraform plan..."
    log_info "Plan file: $plan_file"
    
    local cmd="terraform plan -out=$plan_file"
    
    if [[ -f "$vars_file" ]]; then
        cmd="$cmd -var-file=$vars_file"
    fi
    
    if [[ -n "$extra_args" ]]; then
        cmd="$cmd $extra_args"
    fi
    
    eval "$cmd"
    
    if [[ $? -ne 0 ]]; then
        log_error "Plan failed"
        exit 1
    fi
    
    log_success "Plan saved to: $plan_file"
}

run_apply() {
    local plan_file=${1:-"tfplan"}
    
    log_step "Applying Terraform plan..."
    
    if [[ ! -f "$plan_file" ]]; then
        log_error "Plan file not found: $plan_file"
        exit 1
    fi
    
    # Show plan summary
    log_info "Plan summary:"
    terraform show -json "$plan_file" | jq -r '
        .resource_changes // [] | 
        group_by(.change.actions[0]) | 
        map({key: .[0].change.actions[0], value: length}) | 
        from_entries |
        to_entries | 
        map("\(.key): \(.value)") | 
        .[]
    ' 2>/dev/null || terraform show "$plan_file" | head -20
    
    echo ""
    read -p "Apply this plan? [y/N]: " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        terraform apply "$plan_file"
        
        if [[ $? -eq 0 ]]; then
            log_success "Apply completed successfully"
            rm -f "$plan_file"
        else
            log_error "Apply failed"
            exit 1
        fi
    else
        log_warn "Apply cancelled"
        exit 0
    fi
}