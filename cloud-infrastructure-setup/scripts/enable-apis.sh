#!/bin/bash
# Purpose: Enable required GCP APIs for ML workloads
# Usage:   ./enable-apis.sh [--all|--core|--ml|--container]
# Example: ./enable-apis.sh --all

set -euo pipefail

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PROJECT_ID" ]; then
    echo "Error: No project configured. Run: gcloud config set project YOUR_PROJECT_ID" >&2
    exit 1
fi

echo "Enabling APIs for project: $PROJECT_ID" >&2
echo "" >&2

# Core APIs needed for any GCP work
CORE_APIS=(
    "compute.googleapis.com"
    "storage.googleapis.com"
    "logging.googleapis.com"
    "monitoring.googleapis.com"
)

# ML-specific APIs
ML_APIS=(
    "aiplatform.googleapis.com"
    "bigquery.googleapis.com"
    "notebooks.googleapis.com"
)

# Container/Build APIs
CONTAINER_APIS=(
    "artifactregistry.googleapis.com"
    "cloudbuild.googleapis.com"
    "container.googleapis.com"
    "containerregistry.googleapis.com"
)

# Additional useful APIs
ADDITIONAL_APIS=(
    "cloudresourcemanager.googleapis.com"
    "iam.googleapis.com"
    "cloudbilling.googleapis.com"
    "serviceusage.googleapis.com"
)

enable_api() {
    local api="$1"
    echo -n "Enabling $api... " >&2
    if gcloud services enable "$api" --project="$PROJECT_ID" 2>/dev/null; then
        echo "✓" >&2
    else
        echo "✗ (may already be enabled or insufficient permissions)" >&2
    fi
}

enable_api_group() {
    local group_name="$1"
    shift
    local apis=("$@")
    
    echo "=== $group_name ===" >&2
    for api in "${apis[@]}"; do
        enable_api "$api"
    done
    echo "" >&2
}

case "${1:---core}" in
    --core)
        enable_api_group "Core APIs" "${CORE_APIS[@]}"
        ;;
    --ml)
        enable_api_group "ML APIs" "${ML_APIS[@]}"
        ;;
    --storage)
        enable_api_group "Core APIs" "${CORE_APIS[@]}"
        ;;
    --container)
        enable_api_group "Container/Build APIs" "${CONTAINER_APIS[@]}"
        ;;
    --all)
        enable_api_group "Core APIs" "${CORE_APIS[@]}"
        enable_api_group "ML APIs" "${ML_APIS[@]}"
        enable_api_group "Container/Build APIs" "${CONTAINER_APIS[@]}"
        enable_api_group "Additional APIs" "${ADDITIONAL_APIS[@]}"
        ;;
    *)
        echo "Usage: $0 [--all|--core|--ml|--storage|--container]" >&2
        echo "" >&2
        echo "Options:" >&2
        echo "  --core      Enable core APIs (compute, storage, logging)" >&2
        echo "  --ml        Enable ML APIs (Vertex AI, BigQuery, Notebooks)" >&2
        echo "  --storage   Enable storage APIs" >&2
        echo "  --container Enable container/build APIs (Artifact Registry, Cloud Build)" >&2
        echo "  --all       Enable all recommended APIs (default)" >&2
        exit 1
        ;;
esac

echo "API enablement complete!" >&2
echo "" >&2
echo "To verify enabled APIs:" >&2
echo "  gcloud services list --enabled" >&2
