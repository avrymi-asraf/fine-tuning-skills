#!/bin/bash
# Purpose: Install and configure gcloud CLI for ML workloads
# Usage:   ./setup-gcloud.sh [PROJECT_ID] [REGION]
# Example: ./setup-gcloud.sh my-ml-project us-central1

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="${1:-}"
REGION="${2:-us-central1}"
ZONE="${2:-us-central1}-a"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

detect_os() {
    case "$(uname -s)" in
        Linux*)     OS=Linux;;
        Darwin*)    OS=Mac;;
        CYGWIN*|MINGW*|MSYS*) OS=Windows;;
        *)          OS="UNKNOWN";;
    esac
    echo "$OS"
}

detect_arch() {
    case "$(uname -m)" in
        x86_64)     ARCH=x86_64;;
        arm64|aarch64) ARCH=arm;;
        *)          ARCH="UNKNOWN";;
    esac
    echo "$ARCH"
}

install_gcloud() {
    log_info "Detecting operating system..."
    OS=$(detect_os)
    ARCH=$(detect_arch)
    
    log_info "OS: $OS, Architecture: $ARCH"
    
    if command -v gcloud &> /dev/null; then
        log_info "gcloud CLI is already installed"
        gcloud --version | head -1
        return 0
    fi
    
    case $OS in
        Mac)
            if command -v brew &> /dev/null; then
                log_info "Installing via Homebrew..."
                brew install google-cloud-sdk
            else
                log_info "Installing via direct download..."
                curl https://sdk.cloud.google.com | bash
            fi
            ;;
        Linux)
            log_info "Installing Google Cloud SDK for Linux..."
            
            if [ "$ARCH" = "arm" ]; then
                GCLOUD_TAR="google-cloud-cli-linux-arm.tar.gz"
            else
                GCLOUD_TAR="google-cloud-cli-linux-x86_64.tar.gz"
            fi
            
            curl -O "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/$GCLOUD_TAR"
            tar -xf "$GCLOUD_TAR"
            ./google-cloud-sdk/install.sh --quiet --path-update=true --command-completion=true --usage-reporting=false
            rm "$GCLOUD_TAR"
            
            # Add to PATH for current session
            export PATH="$PWD/google-cloud-sdk/bin:$PATH"
            ;;
        *)
            log_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac
    
    log_info "gcloud CLI installed successfully"
}

initialize_gcloud() {
    log_info "Initializing gcloud CLI..."
    
    # Run gcloud init
    if [ -z "$PROJECT_ID" ]; then
        log_warn "No project ID provided. Running interactive init..."
        gcloud init
    else
        log_info "Setting up with project: $PROJECT_ID"
        
        # Check if already authenticated
        if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q "@"; then
            log_info "Authentication required. Opening browser..."
            gcloud auth login
        fi
        
        # Set project
        gcloud config set project "$PROJECT_ID"
    fi
    
    # Set region and zone
    gcloud config set compute/region "$REGION"
    gcloud config set compute/zone "$ZONE"
    
    log_info "Configuration complete"
    gcloud config list
}

setup_application_default_credentials() {
    log_info "Setting up Application Default Credentials (ADC)..."
    log_info "This is required for Vertex AI SDK and other libraries"
    
    if [ -f "$HOME/.config/gcloud/application_default_credentials.json" ]; then
        log_warn "ADC already exists. Skipping..."
    else
        gcloud auth application-default login
    fi
}

enable_ml_apis() {
    log_info "Enabling required APIs for ML workloads..."
    
    REQUIRED_APIS=(
        "aiplatform.googleapis.com"
        "compute.googleapis.com"
        "storage.googleapis.com"
        "artifactregistry.googleapis.com"
        "cloudbuild.googleapis.com"
        "container.googleapis.com"
        "bigquery.googleapis.com"
        "logging.googleapis.com"
        "monitoring.googleapis.com"
    )
    
    for api in "${REQUIRED_APIS[@]}"; do
        log_info "Enabling $api..."
        gcloud services enable "$api" || log_warn "Failed to enable $api (may already be enabled or insufficient permissions)"
    done
    
    log_info "APIs enabled. This may take a few minutes to propagate."
}

create_service_account() {
    local sa_name="ml-training-sa"
    local sa_email="${sa_name}@${PROJECT_ID}.iam.gserviceaccount.com"
    
    log_info "Creating service account for ML training: $sa_name"
    
    # Check if service account exists
    if gcloud iam service-accounts list --format="value(email)" | grep -q "$sa_email"; then
        log_warn "Service account $sa_email already exists"
    else
        gcloud iam service-accounts create "$sa_name" \
            --display-name="ML Training Service Account" \
            --description="Service account for running ML training jobs"
        log_info "Service account created: $sa_email"
    fi
    
    # Grant required roles
    log_info "Granting IAM roles to service account..."
    
    ROLES=(
        "roles/aiplatform.user"
        "roles/storage.admin"
        "roles/artifactregistry.reader"
        "roles/artifactregistry.writer"
        "roles/cloudbuild.builds.editor"
        "roles/logging.logWriter"
        "roles/monitoring.metricWriter"
    )
    
    for role in "${ROLES[@]}"; do
        log_info "Granting $role..."
        gcloud projects add-iam-policy-binding "$PROJECT_ID" \
            --member="serviceAccount:$sa_email" \
            --role="$role" \
            --condition=None || log_warn "Failed to grant $role"
    done
    
    log_info "Service account setup complete: $sa_email"
    echo ""
    echo "To use this service account in training jobs, set:"
    echo "  export TRAINING_SERVICE_ACCOUNT=$sa_email"
}

create_gcs_bucket() {
    local bucket_name="${PROJECT_ID}-ml-bucket"
    
    log_info "Creating GCS bucket for ML artifacts: $bucket_name"
    
    if gsutil ls -b "gs://$bucket_name" &>/dev/null; then
        log_warn "Bucket gs://$bucket_name already exists"
    else
        gsutil mb -l "$REGION" "gs://$bucket_name"
        log_info "Bucket created: gs://$bucket_name"
        
        # Enable versioning for safety
        gsutil versioning set on "gs://$bucket_name"
        log_info "Object versioning enabled"
    fi
    
    echo ""
    echo "To use this bucket, set:"
    echo "  export GCS_BUCKET=gs://$bucket_name"
}

print_next_steps() {
    echo ""
    echo "========================================"
    echo "  GCP Setup Complete!"
    echo "========================================"
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Verify configuration:"
    echo "   gcloud config list"
    echo ""
    echo "2. Test access:"
    echo "   gcloud projects describe $PROJECT_ID"
    echo ""
    echo "3. Set up environment variables:"
    echo "   cp scripts/set-env.sh .env"
    echo "   # Edit .env with your values, then:"
    echo "   source .env"
    echo ""
    echo "4. Check permissions:"
    echo "   ./scripts/check-permissions.sh"
    echo ""
    echo "5. Install Vertex AI SDK:"
    echo "   pip install google-cloud-aiplatform"
    echo ""
    echo "6. Create a billing budget alert:"
    echo "   gcloud billing budgets create --help"
    echo ""
}

main() {
    echo "========================================"
    echo "  GCP ML Infrastructure Setup"
    echo "========================================"
    echo ""
    
    # Check if project ID was provided
    if [ -z "${PROJECT_ID:-}" ]; then
        echo "Usage: $0 [PROJECT_ID] [REGION]" >&2
        echo "" >&2
        echo "Example:" >&2
        echo "  $0 my-ml-project us-central1" >&2
        echo "" >&2
        echo "If PROJECT_ID is not provided, interactive setup will be used." >&2
        echo "" >&2
    fi
    
    install_gcloud
    initialize_gcloud
    setup_application_default_credentials
    
    # Only continue if we have a project ID
    if [ -n "$PROJECT_ID" ]; then
        enable_ml_apis
        create_service_account
        create_gcs_bucket
    else
        log_warn "Project ID not specified. Skipping API enablement and resource creation."
        log_info "Run again with PROJECT_ID to complete setup."
    fi
    
    print_next_steps
}

main "$@"
