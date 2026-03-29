#!/bin/bash
# Quick planning with common options

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/terraform-helpers.sh"

ENVIRONMENT="dev"
TARGET=""
REPLACE=""

usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -e, --environment    Environment (default: dev)"
    echo "  -t, --target         Target specific resource (e.g., module.vpc)"
    echo "  -r, --replace        Force replace resource (e.g., google_compute_network.vpc)"
    echo "  -h, --help           Show help"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment) ENVIRONMENT="$2"; shift 2 ;;
        -t|--target) TARGET="$2"; shift 2 ;;
        -r|--replace) REPLACE="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

cd "$PROJECT_ROOT"

init_terraform
select_workspace "$ENVIRONMENT"

# Build plan command
PLAN_CMD="terraform plan"
VARS_FILE="environments/${ENVIRONMENT}/terraform.tfvars"
[[ -f "$VARS_FILE" ]] && PLAN_CMD="$PLAN_CMD -var-file=$VARS_FILE"

if [[ -n "$TARGET" ]]; then
    PLAN_CMD="$PLAN_CMD -target=$TARGET"
fi

if [[ -n "$REPLACE" ]]; then
    PLAN_CMD="$PLAN_CMD -replace=$REPLACE"
fi

log_step "Running: $PLAN_CMD"
eval "$PLAN_CMD"