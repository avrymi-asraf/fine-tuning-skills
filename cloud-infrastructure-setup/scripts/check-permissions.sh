#!/bin/bash
# check-permissions.sh - Verify IAM permissions for GCP ML workloads
#
# Usage:
#   ./check-permissions.sh [SERVICE_ACCOUNT_EMAIL]
#
#   If SERVICE_ACCOUNT_EMAIL is not provided, checks current user permissions

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
SERVICE_ACCOUNT="${1:-}"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

# Check if gcloud is installed
check_gcloud() {
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is not installed"
        exit 1
    fi
    log_info "gcloud CLI found"
}

# Get current identity
get_identity() {
    if [ -n "$SERVICE_ACCOUNT" ]; then
        echo "$SERVICE_ACCOUNT"
    else
        gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1
    fi
}

# Check if a permission is granted
check_permission() {
    local member="$1"
    local permission="$2"
    
    # This is a simplified check - actual IAM policy testing requires testIamPermissions API
    # For now, we check role assignments
    local roles
    roles=$(gcloud projects get-iam-policy "$PROJECT_ID" --flatten="bindings[].members" --format="table(bindings.role)" --filter="bindings.members:$member" 2>/dev/null | tail -n +2 || true)
    
    echo "$roles"
}

# Check required roles for ML training
check_ml_roles() {
    local member="$1"
    
    log_section "Checking ML-Required IAM Roles"
    
    declare -A REQUIRED_ROLES=(
        ["roles/aiplatform.user"]="Vertex AI User - Access to AI Platform resources"
        ["roles/storage.objectViewer"]="Storage Object Viewer - Read GCS objects"
        ["roles/storage.objectCreator"]="Storage Object Creator - Write GCS objects"
        ["roles/storage.objectAdmin"]="Storage Object Admin - Full GCS object access"
        ["roles/storage.admin"]="Storage Admin - Full GCS access (includes above)"
        ["roles/artifactregistry.reader"]="Artifact Registry Reader - Pull container images"
        ["roles/artifactregistry.writer"]="Artifact Registry Writer - Push container images"
        ["roles/logging.logWriter"]="Logs Writer - Write training logs"
        ["roles/monitoring.metricWriter"]="Monitoring Metric Writer - Write metrics"
    )
    
    local missing_roles=()
    
    for role in "${!REQUIRED_ROLES[@]}"; do
        local description="${REQUIRED_ROLES[$role]}"
        
        # Check if role is assigned
        if gcloud projects get-iam-policy "$PROJECT_ID" --flatten="bindings[].members" --filter="bindings.members:$member AND bindings.role:$role" --format="value(bindings.role)" 2>/dev/null | grep -q "$role"; then
            echo "  ✓ $role"
            echo "    $description"
        else
            # Check for broader role that includes these permissions
            local has_broad_role=false
            case $role in
                roles/storage.objectViewer|roles/storage.objectCreator)
                    if gcloud projects get-iam-policy "$PROJECT_ID" --flatten="bindings[].members" --filter="bindings.members:$member AND bindings.role:roles/storage.admin" --format="value(bindings.role)" 2>/dev/null | grep -q "roles/storage.admin"; then
                        echo "  ✓ $role (via roles/storage.admin)"
                        has_broad_role=true
                    fi
                    ;;
                roles/artifactregistry.reader)
                    if gcloud projects get-iam-policy "$PROJECT_ID" --flatten="bindings[].members" --filter="bindings.members:$member AND bindings.role:roles/artifactregistry.writer" --format="value(bindings.role)" 2>/dev/null | grep -q "roles/artifactregistry.writer"; then
                        echo "  ✓ $role (via roles/artifactregistry.writer)"
                        has_broad_role=true
                    fi
                    ;;
            esac
            
            if [ "$has_broad_role" = false ]; then
                echo "  ✗ $role - NOT ASSIGNED"
                echo "    $description"
                missing_roles+=("$role")
            fi
        fi
    done
    
    echo ""
    if [ ${#missing_roles[@]} -eq 0 ]; then
        log_info "All required ML roles are assigned"
    else
        log_warn "Missing ${#missing_roles[@]} role(s)"
        echo ""
        echo "To grant missing roles:"
        for role in "${missing_roles[@]}"; do
            echo "  gcloud projects add-iam-policy-binding $PROJECT_ID \\"
            echo "    --member=\"user:$member\" \\"
            echo "    --role=\"$role\""
        done
    fi
}

# Check API enablement
check_apis() {
    log_section "Checking Enabled APIs"
    
    REQUIRED_APIS=(
        "aiplatform.googleapis.com"
        "compute.googleapis.com"
        "storage.googleapis.com"
        "artifactregistry.googleapis.com"
        "cloudbuild.googleapis.com"
        "logging.googleapis.com"
        "monitoring.googleapis.com"
    )
    
    local disabled_apis=()
    
    for api in "${REQUIRED_APIS[@]}"; do
        if gcloud services list --enabled --format="value(config.name)" 2>/dev/null | grep -q "^$api$"; then
            echo "  ✓ $api"
        else
            echo "  ✗ $api - NOT ENABLED"
            disabled_apis+=("$api")
        fi
    done
    
    echo ""
    if [ ${#disabled_apis[@]} -eq 0 ]; then
        log_info "All required APIs are enabled"
    else
        log_warn "${#disabled_apis[@]} API(s) not enabled"
        echo ""
        echo "To enable missing APIs:"
        for api in "${disabled_apis[@]}"; do
            echo "  gcloud services enable $api"
        done
    fi
}

# Check quota availability
check_quotas() {
    log_section "Checking Resource Quotas"
    
    local region
    region=$(gcloud config get-value compute/region 2>/dev/null)
    
    if [ -z "$region" ]; then
        log_warn "No region configured, skipping quota check"
        return
    fi
    
    log_info "Checking quotas for region: $region"
    
    # Get quota information
    local quota_info
    quota_info=$(gcloud compute regions describe "$region" --format="json" 2>/dev/null || echo "{}")
    
    # Check key ML quotas
    local ml_quotas=(
        "CPUS"
        "DISKS_TOTAL_GB"
        "IN_USE_ADDRESSES"
        "GPUS_ALL_REGIONS"
    )
    
    for quota_name in "${ml_quotas[@]}"; do
        local quota_value
        quota_value=$(echo "$quota_info" | python3 -c "import sys, json; data = json.load(sys.stdin); quotas = data.get('quotas', []); match = [q for q in quotas if q.get('metric') == '$quota_name']; print(f\"{match[0].get('limit', 0)}\" if match else 'N/A')" 2>/dev/null || echo "N/A")
        
        if [ "$quota_value" != "N/A" ] && [ "$quota_value" != "0" ]; then
            echo "  ✓ $quota_name: limit = $quota_value"
        else
            echo "  ⚠ $quota_name: Could not retrieve quota or limit is 0"
        fi
    done
    
    echo ""
    echo "To view all quotas:"
    echo "  gcloud compute regions describe $region"
}

# Check service account key status
check_service_account_keys() {
    if [ -z "$SERVICE_ACCOUNT" ]; then
        return
    fi
    
    log_section "Checking Service Account Keys"
    
    local keys
    keys=$(gcloud iam service-accounts keys list --iam-account="$SERVICE_ACCOUNT" --format="table(keyAlgorithm, validAfterTime, validBeforeTime)" 2>/dev/null || true)
    
    if [ -n "$keys" ]; then
        echo "$keys"
        
        # Check for expired keys
        local now
        now=$(date -u +%s)
        
        # This is a simplified check - in practice you'd parse dates properly
        log_info "Review key expiration dates above"
    else
        log_warn "No keys found or cannot access key list"
    fi
}

# Test actual resource access
test_resource_access() {
    log_section "Testing Resource Access"
    
    # Test GCS access
    local test_bucket="gs://${PROJECT_ID}-ml-bucket"
    if gsutil ls "$test_bucket" &>/dev/null; then
        echo "  ✓ GCS bucket access: $test_bucket"
    else
        echo "  ✗ GCS bucket access failed: $test_bucket"
        echo "    Create bucket: gsutil mb -l $GCP_REGION $test_bucket"
    fi
    
    # Test Vertex AI access
    if gcloud ai custom-jobs list --region="$(gcloud config get-value compute/region 2>/dev/null || echo us-central1)" --limit=1 &>/dev/null; then
        echo "  ✓ Vertex AI API access"
    else
        echo "  ✗ Vertex AI API access failed"
        echo "    Ensure aiplatform.googleapis.com is enabled"
    fi
    
    # Test Artifact Registry access
    local region
    region=$(gcloud config get-value compute/region 2>/dev/null | cut -d- -f1,2 || echo "us-central1")
    if gcloud artifacts repositories list --location="$region" &>/dev/null; then
        echo "  ✓ Artifact Registry access"
    else
        echo "  ⚠ Artifact Registry access failed (may not have any repositories)"
    fi
}

# Print summary
print_summary() {
    log_section "Summary"
    
    echo "Project: $PROJECT_ID"
    echo "Identity: $(get_identity)"
    echo ""
    echo "Run this check anytime to verify permissions:"
    echo "  ./scripts/check-permissions.sh"
    echo ""
    echo "For service account checks:"
    echo "  ./scripts/check-permissions.sh service-account@project.iam.gserviceaccount.com"
}

main() {
    echo "========================================"
    echo "  GCP Permissions Check"
    echo "========================================"
    
    check_gcloud
    
    if [ -z "$PROJECT_ID" ]; then
        log_error "No project configured. Run: gcloud config set project YOUR_PROJECT_ID"
        exit 1
    fi
    
    log_info "Project: $PROJECT_ID"
    log_info "Identity: $(get_identity)"
    
    local member
    if [ -n "$SERVICE_ACCOUNT" ]; then
        member="serviceAccount:$SERVICE_ACCOUNT"
    else
        member="user:$(get_identity)"
    fi
    
    check_ml_roles "$member"
    check_apis
    check_quotas
    
    if [ -n "$SERVICE_ACCOUNT" ]; then
        check_service_account_keys
    fi
    
    test_resource_access
    print_summary
}

main "$@"
