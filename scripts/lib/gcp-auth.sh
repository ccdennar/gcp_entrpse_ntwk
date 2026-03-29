authenticate_gcp() {
    local project_id=$1

    log_step "Checking GCP authentication..."

    # In CI (Cloud Build), GOOGLE_APPLICATION_CREDENTIALS is set — skip interactive login
    if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]; then
        log_info "Using service account from GOOGLE_APPLICATION_CREDENTIALS"
        gcloud auth activate-service-account \
            --key-file="$GOOGLE_APPLICATION_CREDENTIALS" 2>/dev/null || true
        gcloud config set project "$project_id" > /dev/null 2>&1
        log_success "Authenticated via service account: $project_id"
        return 0
    fi

    # Local dev: interactive login
    if ! gcloud auth print-access-token &> /dev/null; then
        log_warn "Not authenticated to GCP"
        gcloud auth application-default login
    fi

    gcloud config set project "$project_id" > /dev/null 2>&1
    log_success "Authenticated to project: $project_id"
}