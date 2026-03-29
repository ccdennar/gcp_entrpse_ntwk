#!/bin/bash
# Main deployment script for GCP VPC Enterprise

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/gcp-auth.sh"
source "$SCRIPT_DIR/lib/terraform-helpers.sh"

# Default values
ENVIRONMENT="dev"
VARS_FILE=""
AUTO_APPROVE=false
SKIP_VALIDATION=false
GENERATE_BACKEND=false
PLAN_ONLY=false
DESTROY=false

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Deploy GCP VPC Enterprise infrastructure

OPTIONS:
    -e, --environment    Environment (dev|staging|prod) [default: dev]
    -f, --vars-file      Path to terraform.tfvars file
    -b, --backend        Generate and use GCS backend configuration
    -y, --yes            Auto-approve apply (non-interactive)
    -p, --plan-only      Run plan only, skip apply
    -d, --destroy        Destroy infrastructure (with confirmation)
    --skip-validation    Skip pre-deployment validation
    -h, --help           Show this help message

EXAMPLES:
    # Deploy to dev with interactive approval
    ./scripts/deploy.sh -e dev

    # Deploy to production with specific vars file
    ./scripts/deploy.sh -e prod -f environments/prod/terraform.tfvars -b -y

    # Plan only
    ./scripts/deploy.sh -e staging -p

    # Destroy with confirmation
    ./scripts/deploy.sh -e dev -d

EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -f|--vars-file)
                VARS_FILE="$2"
                shift 2
                ;;
            -b|--backend)
                GENERATE_BACKEND=true
                shift
                ;;
            -y|--yes)
                AUTO_APPROVE=true
                shift
                ;;
            -p|--plan-only)
                PLAN_ONLY=true
                shift
                ;;
            -d|--destroy)
                DESTROY=true
                shift
                ;;
            --skip-validation)
                SKIP_VALIDATION=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

main() {
    parse_args "$@"
    
    log_header "GCP VPC Enterprise Deployment"
    log_info "Environment: $ENVIRONMENT"
    log_info "Working directory: $PROJECT_ROOT"
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Determine vars file
    if [[ -z "$VARS_FILE" ]]; then
        if [[ -f "environments/${ENVIRONMENT}/terraform.tfvars" ]]; then
            VARS_FILE="environments/${ENVIRONMENT}/terraform.tfvars"
        elif [[ -f "terraform.tfvars" ]]; then
            VARS_FILE="terraform.tfvars"
        else
            log_error "No terraform.tfvars found. Use -f to specify."
            exit 1
        fi
    fi
    
    log_info "Using vars file: $VARS_FILE"
    
    # Extract project_id from vars file
    local project_id=$(grep -E '^project_id\s*=' "$VARS_FILE" | cut -d'"' -f2 | tr -d ' ')
    
    if [[ -z "$project_id" ]]; then
        log_error "Could not extract project_id from $VARS_FILE"
        exit 1
    fi
    
    log_info "Target project: $project_id"
    
    # Pre-deployment checks
    if [[ "$SKIP_VALIDATION" == false ]]; then
        check_gcloud
        check_terraform
        authenticate_gcp "$project_id"
        enable_apis "$project_id"
        validate_iam_permissions "$project_id"
    fi
    
    # Backend configuration
    local backend_config=""
    if [[ "$GENERATE_BACKEND" == true ]]; then
        generate_backend_config "$ENVIRONMENT" "$project_id"
        backend_config="environments/${ENVIRONMENT}/backend.conf"
    fi
    
    # Terraform workflow
    init_terraform "$backend_config"
    select_workspace "$ENVIRONMENT"
    
    # Handle destroy
    if [[ "$DESTROY" == true ]]; then
        log_warn "DESTROY mode selected!"
        read -p "Type 'destroy' to confirm destruction of $ENVIRONMENT infrastructure: " confirm
        if [[ "$confirm" == "destroy" ]]; then
            terraform destroy -var-file="$VARS_FILE"
            log_success "Destruction completed"
        else
            log_info "Destruction cancelled"
        fi
        exit 0
    fi
    
    # Plan
    local plan_file="tfplan-${ENVIRONMENT}"
    run_plan "$plan_file" "$VARS_FILE"
    
    # Apply (unless plan-only)
    if [[ "$PLAN_ONLY" == false ]]; then
        if [[ "$AUTO_APPROVE" == true ]]; then
            log_step "Auto-applying..."
            terraform apply -auto-approve "$plan_file"
            rm -f "$plan_file"
            log_success "Deployment completed!"
        else
            run_apply "$plan_file"
        fi
        
        # Output results
        log_step "Deployment outputs:"
        terraform output -json | jq -r '
            to_entries | 
            map(select(.key != "security_summary")) | 
            map("\(.key): \(.value.value)") | 
            .[]
        ' 2>/dev/null || terraform output
    else
        log_success "Plan completed. Review $plan_file and run apply separately."
    fi
}

main "$@"