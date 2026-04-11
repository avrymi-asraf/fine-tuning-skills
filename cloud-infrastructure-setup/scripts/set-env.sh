#!/bin/bash
# set-env.sh - Environment variables template for GCP ML workloads
# 
# Usage:
#   1. Copy this file: cp set-env.sh .env
#   2. Edit .env with your values
#   3. Source it: source .env
#   4. Or use with direnv: mv .env .envrc && direnv allow

# =============================================================================
# REQUIRED: Project Configuration
# =============================================================================

# Your GCP project ID (found in Cloud Console)
export GCP_PROJECT_ID="your-project-id"

# Primary region for resources (us-central1, us-east1, europe-west1, asia-east1, etc.)
export GCP_REGION="us-central1"

# Zone within the region (typically region + letter suffix)
export GCP_ZONE="us-central1-a"

# =============================================================================
# REQUIRED: Vertex AI Configuration
# =============================================================================

# Vertex AI location (usually same as region)
export VERTEX_AI_LOCATION="${GCP_REGION}"

# Service account for training jobs (created by setup-gcloud.sh)
export TRAINING_SERVICE_ACCOUNT="ml-training-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

# =============================================================================
# REQUIRED: Storage Configuration
# =============================================================================

# Main bucket for ML artifacts
export GCS_BUCKET="gs://${GCP_PROJECT_ID}-ml-bucket"

# Staging bucket for temporary files
export GCS_STAGING_BUCKET="gs://${GCP_PROJECT_ID}-ml-staging"

# Model artifacts location
export GCS_MODEL_DIR="${GCS_BUCKET}/models"

# Training data location
export GCS_DATA_DIR="${GCS_BUCKET}/data"

# Checkpoints location
export GCS_CHECKPOINT_DIR="${GCS_BUCKET}/checkpoints"

# =============================================================================
# Container Registry Configuration
# =============================================================================

# Artifact Registry location (region-docker.pkg.dev/project/repository)
export ARTIFACT_REGISTRY="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/ml-images"

# Legacy Container Registry (gcr.io) - deprecated, prefer Artifact Registry
export CONTAINER_REGISTRY="gcr.io/${GCP_PROJECT_ID}"

# Default training image tag
export TRAINING_IMAGE_TAG="latest"

# =============================================================================
# Compute Configuration
# =============================================================================

# Default machine type for training
export TRAINING_MACHINE_TYPE="n1-standard-4"

# Default GPU type (leave empty for CPU-only training)
export TRAINING_ACCELERATOR_TYPE="NVIDIA_TESLA_T4"

# Default GPU count
export TRAINING_ACCELERATOR_COUNT="1"

# =============================================================================
# Training Configuration
# =============================================================================

# Default display name prefix for jobs
export JOB_NAME_PREFIX="training"

# Enable/disable Spot VMs (true/false)
export USE_SPOT_VMS="true"

# Max nodes for distributed training
export MAX_WORKER_NODES="1"

# =============================================================================
# Cost Management
# =============================================================================

# Billing account ID for budget alerts
export BILLING_ACCOUNT_ID="XXXXXX-XXXXXX-XXXXXX"

# Monthly budget amount in USD
export MONTHLY_BUDGET="1000"

# Cost alert thresholds (comma-separated percentages)
export BUDGET_ALERT_THRESHOLDS="50,80,100"

# =============================================================================
# Optional: Advanced Configuration
# =============================================================================

# Network configuration (if using VPC)
export VPC_NETWORK=""
export VPC_SUBNET=""

# Cloud Build configuration
export CLOUD_BUILD_TIMEOUT="3600"

# BigQuery dataset for ML metadata
export BQ_DATASET="ml_metadata"

# =============================================================================
# Convenience Aliases (optional)
# =============================================================================

# Quick gcloud project switch
alias gcp-proj="gcloud config set project $GCP_PROJECT_ID"

# Quick region switch
alias gcp-region="gcloud config set compute/region $GCP_REGION"

# List active configurations
alias gcp-configs="gcloud config configurations list"

# =============================================================================
# Validation Functions
# =============================================================================

# Verify environment is properly configured
verify_gcp_env() {
    local errors=0
    
    echo "Verifying GCP environment configuration..."
    echo ""
    
    # Check required variables
    if [ -z "$GCP_PROJECT_ID" ] || [ "$GCP_PROJECT_ID" = "your-project-id" ]; then
        echo "❌ GCP_PROJECT_ID is not set or has default value"
        errors=$((errors + 1))
    else
        echo "✓ GCP_PROJECT_ID: $GCP_PROJECT_ID"
    fi
    
    if [ -z "$GCP_REGION" ]; then
        echo "❌ GCP_REGION is not set"
        errors=$((errors + 1))
    else
        echo "✓ GCP_REGION: $GCP_REGION"
    fi
    
    # Verify gcloud is authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q "@"; then
        echo "❌ Not authenticated with gcloud"
        errors=$((errors + 1))
    else
        local account
        account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
        echo "✓ Authenticated as: $account"
    fi
    
    # Verify project access
    if ! gcloud projects describe "$GCP_PROJECT_ID" &>/dev/null; then
        echo "❌ Cannot access project: $GCP_PROJECT_ID"
        errors=$((errors + 1))
    else
        echo "✓ Project accessible: $GCP_PROJECT_ID"
    fi
    
    # Verify GCS bucket exists
    if ! gsutil ls "$GCS_BUCKET" &>/dev/null; then
        echo "⚠ GCS bucket does not exist: $GCS_BUCKET"
    else
        echo "✓ GCS bucket accessible: $GCS_BUCKET"
    fi
    
    echo ""
    if [ $errors -eq 0 ]; then
        echo "✅ Environment verification passed"
        return 0
    else
        echo "❌ Environment verification failed ($errors errors)"
        return 1
    fi
}

# Print current configuration
show_gcp_config() {
    echo "Current GCP Configuration:"
    echo "=========================="
    echo ""
    echo "Project ID:        $GCP_PROJECT_ID"
    echo "Region:            $GCP_REGION"
    echo "Zone:              $GCP_ZONE"
    echo "Vertex AI Loc:     $VERTEX_AI_LOCATION"
    echo "Service Account:   $TRAINING_SERVICE_ACCOUNT"
    echo "GCS Bucket:        $GCS_BUCKET"
    echo "Artifact Registry: $ARTIFACT_REGISTRY"
    echo "Machine Type:      $TRAINING_MACHINE_TYPE"
    echo "Accelerator:       $TRAINING_ACCELERATOR_TYPE"
    echo "Spot VMs:          $USE_SPOT_VMS"
    echo ""
    echo "gcloud config:"
    gcloud config list --format='table(property,value)'
}

# Export functions for use in other scripts
export -f verify_gcp_env
export -f show_gcp_config

# =============================================================================
# Auto-validate on source (optional - uncomment to enable)
# =============================================================================

# verify_gcp_env
