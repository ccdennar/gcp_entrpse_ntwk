#!/bin/bash
# Force delete ALL GCP resources for a specific VPC

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

ENVIRONMENT=${1:-dev}
VARS_FILE="$PROJECT_ROOT/environments/${ENVIRONMENT}/terraform.tfvars"

# Extract project_id from terraform.tfvars
if [[ -f "$VARS_FILE" ]]; then
    PROJECT_ID=$(grep '^project_id' "$VARS_FILE" | head -1 | cut -d'"' -f2)
else
    echo "Error: $VARS_FILE not found"
    exit 1
fi

if [[ -z "$PROJECT_ID" ]]; then
    echo "Error: Could not extract project_id from $VARS_FILE"
    exit 1
fi

# If project_id looks like a number, resolve to the string ID
if [[ "$PROJECT_ID" =~ ^[0-9]+$ ]]; then
    echo "project_id looks like a number ($PROJECT_ID), resolving to project ID string..."
    PROJECT_ID=$(gcloud projects describe "$PROJECT_ID" --format="value(projectId)")
    echo "Resolved project ID: $PROJECT_ID"
fi

VPC_NAME="${ENVIRONMENT}-fresh-84-vpc"

echo "Force deleting VPC: $VPC_NAME"
echo "Project: $PROJECT_ID"

# Check if VPC exists
if gcloud compute networks describe "$VPC_NAME" --project="$PROJECT_ID" >/dev/null 2>&1; then
    VPC_EXISTS=true
else
    VPC_EXISTS=false
fi

if [[ "$VPC_EXISTS" == "false" ]]; then
    echo "VPC $VPC_NAME not found, trying to find any matching VPCs..."
    VPC_NAME=$(gcloud compute networks list --project="$PROJECT_ID" --filter="name:${ENVIRONMENT}" --format="value(name)" | head -1)
    if [[ -z "$VPC_NAME" ]]; then
        echo "No matching VPCs found. All networks in project:"
        gcloud compute networks list --project="$PROJECT_ID"
        exit 0
    fi
    echo "Found VPC: $VPC_NAME"
fi

echo "1. Deleting Firewall Rules for $VPC_NAME..."
gcloud compute firewall-rules list --project="$PROJECT_ID" --filter="network:$VPC_NAME" --format="value(name)" 2>/dev/null | \
while read -r fw; do
    if [[ -n "$fw" ]]; then
        echo "  Deleting: $fw"
        gcloud compute firewall-rules delete "$fw" --project="$PROJECT_ID" --quiet 2>/dev/null || true
    fi
done

echo "2. Finding all regions with subnets in $VPC_NAME..."
REGIONS=$(gcloud compute networks subnets list --project="$PROJECT_ID" --network="$VPC_NAME" --format="value(region)" 2>/dev/null)
REGIONS=$(echo "$REGIONS" | sort -u | sed 's|https://www.googleapis.com/compute/v1/projects/'"$PROJECT_ID"'/regions/||')

if [[ -z "$REGIONS" ]]; then
    echo "  No subnets found, using default regions..."
    REGIONS="us-central1 us-east1 europe-west1"
fi

echo "   Regions: $REGIONS"

echo "3. Deleting Subnets in $VPC_NAME..."
for region in $REGIONS; do
    echo "  Region: $region"
    SUBNETS=$(gcloud compute networks subnets list --project="$PROJECT_ID" --network="$VPC_NAME" --regions="$region" --format="value(name)" 2>/dev/null)
    for subnet in $SUBNETS; do
        if [[ -n "$subnet" ]]; then
            echo "    Deleting: $subnet"
            gcloud compute networks subnets delete "$subnet" --project="$PROJECT_ID" --region="$region" --quiet 2>/dev/null || true
        fi
    done
done

echo "4. Deleting Routers and NATs (all regions, global sweep)..."
while IFS=$'\t' read -r router region; do
    [[ -z "$router" ]] && continue
    region=$(echo "$region" | awk -F/ '{print $NF}')
    echo "  Router: $router ($region)"

    # Get NATs into array first — no nested pipes
    mapfile -t NATS < <(gcloud compute routers nats list         --project="$PROJECT_ID"         --router="$router"         --region="$region"         --format="value(name)" 2>/dev/null)

    for nat in "${NATS[@]}"; do
        [[ -z "$nat" ]] && continue
        echo "    Deleting NAT: $nat"
        gcloud compute routers nats delete "$nat"             --project="$PROJECT_ID"             --router="$router"             --region="$region"             --quiet 2>/dev/null && echo "    NAT $nat deleted" || echo "    NAT $nat delete failed"
    done

    echo "  Deleting router: $router"
    gcloud compute routers delete "$router"         --project="$PROJECT_ID"         --region="$region"         --quiet 2>/dev/null && echo "  Router $router deleted" || echo "  Router $router delete failed"

done < <(gcloud compute routers list --project="$PROJECT_ID" --format="value(name,region)" 2>/dev/null)

echo "  Routers remaining:"
gcloud compute routers list --project="$PROJECT_ID" 2>/dev/null || echo "  None"

echo "5. Deleting Global Addresses..."
ADDRS=$(gcloud compute addresses list --project="$PROJECT_ID" --global --format="value(name)" 2>/dev/null)
for addr in $ADDRS; do
    if [[ -n "$addr" ]]; then
        echo "  Deleting: $addr"
        gcloud compute addresses delete "$addr" --project="$PROJECT_ID" --global --quiet 2>/dev/null || true
    fi
done

echo "6. Deleting Regional Addresses..."
for region in $REGIONS; do
    ADDRS=$(gcloud compute addresses list --project="$PROJECT_ID" --regions="$region" --format="value(name)" 2>/dev/null)
    for addr in $ADDRS; do
        if [[ -n "$addr" ]]; then
            gcloud compute addresses delete "$addr" --project="$PROJECT_ID" --region="$region" --quiet 2>/dev/null || true
        fi
    done
done

echo "7. Force removing ALL routers in ALL regions (global sweep)..."
ALL_ROUTERS=$(gcloud compute routers list --project="$PROJECT_ID"     --format="value(name,region)" 2>/dev/null)

if [[ -z "$ALL_ROUTERS" ]]; then
    echo "  No routers found"
else
    echo "$ALL_ROUTERS" | while read -r router region; do
        [[ -z "$router" ]] && continue
        region=$(echo "$region" | awk -F/ '{print $NF}')
        echo "  Found router: $router in $region"

        # Delete NATs first
        NATS=$(gcloud compute routers nats list             --project="$PROJECT_ID"             --router="$router"             --region="$region"             --format="value(name)" 2>/dev/null)
        for nat in $NATS; do
            echo "    Deleting NAT: $nat"
            gcloud compute routers nats delete "$nat"                 --project="$PROJECT_ID"                 --router="$router"                 --region="$region"                 --quiet 2>/dev/null && echo "    NAT deleted" || echo "    NAT delete failed"
        done

        # Delete the router
        gcloud compute routers delete "$router"             --project="$PROJECT_ID"             --region="$region"             --quiet 2>/dev/null && echo "  Router deleted: $router" || echo "  Router delete failed: $router"
    done
fi

echo "  Remaining routers after sweep:"
gcloud compute routers list --project="$PROJECT_ID" 2>/dev/null || echo "  None"

echo "7b. Removing service networking peerings..."
gcloud services vpc-peerings delete     --service=servicenetworking.googleapis.com     --network="$VPC_NAME"     --project="$PROJECT_ID"     --quiet 2>/dev/null || true

# Also remove any other peerings on the VPC
gcloud compute networks peerings list     --network="$VPC_NAME"     --project="$PROJECT_ID"     --format="value(name)" 2>/dev/null | while read -r peering; do
    if [[ -n "$peering" ]]; then
        echo "  Removing peering: $peering"
        gcloud compute networks peerings delete "$peering"             --network="$VPC_NAME"             --project="$PROJECT_ID"             --quiet 2>/dev/null || true
    fi
done

echo "8. Finally deleting VPC: $VPC_NAME"
# Retry up to 3 times in case dependencies need a moment to clear
for attempt in 1 2 3; do
    if gcloud compute networks delete "$VPC_NAME" --project="$PROJECT_ID" --quiet 2>/dev/null; then
        echo "  VPC deleted successfully"
        break
    else
        echo "  Attempt $attempt failed, waiting 10s..."
        sleep 10
    fi
done

echo ""
echo "Done. Remaining networks:"
gcloud compute networks list --project="$PROJECT_ID" 2>/dev/null

echo "Remaining subnets:"
gcloud compute networks subnets list --project="$PROJECT_ID" 2>/dev/null || echo "None"
