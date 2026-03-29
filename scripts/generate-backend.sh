#!/bin/bash
# Generate GCS backend configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"

ENVIRONMENT=${1:-""}
PROJECT_ID=${2:-""}

if [[ -z "$ENVIRONMENT" || -z "$PROJECT_ID" ]]; then
    echo "Usage: $(basename "$0") <environment> <project_id>"
    exit 1
fi

BUCKET_NAME="tf-state-${PROJECT_ID}-${ENVIRONMENT}"
REGION="us-central1"

log_header "Generating Backend Configuration"

log_info "Environment: $ENVIRONMENT"
log_info "Project: $PROJECT_ID"
log_info "Bucket: $BUCKET_NAME"

# Create bucket if needed
if ! gsutil ls "gs://${BUCKET_NAME}" &> /dev/null; then
    log_step "Creating GCS bucket..."
    gsutil mb -p "$PROJECT_ID" -l "$REGION" "gs://${BUCKET_NAME}"
    gsutil versioning set on "gs://${BUCKET_NAME}"
    log_success "Bucket created"
else
    log_info "Bucket already exists"
fi

# Generate backend file
mkdir -p "environments/${ENVIRONMENT}"

cat > "environments/${ENVIRONMENT}/backend.conf" << EOF
bucket  = "${BUCKET_NAME}"
prefix  = "terraform/state"
project = "${PROJECT_ID}"
EOF

log_success "Backend config created: environments/${ENVIRONMENT}/backend.conf"

cat << EOF

To use this backend, run:
    terraform init -backend-config=environments/${ENVIRONMENT}/backend.conf -reconfigure
EOF