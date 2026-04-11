#!/bin/bash
# Purpose: Create and configure a GCS bucket for ML artifacts
# Usage:   ./setup-bucket.sh <bucket-name> --location=<region>
#
# Examples:
#   ./setup-bucket.sh my-project-ml-artifacts --location=us-central1
#   ./setup-bucket.sh my-project-ml-artifacts --location=us-central1 --versioning
#   ./setup-bucket.sh my-project-ml-artifacts --location=us-central1 --no-lifecycle

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat >&2 << 'EOF'
Usage: setup-bucket.sh <bucket-name> [options]

Arguments:
  bucket-name             Name for the GCS bucket (without gs:// prefix)

Options:
  --location=REGION       GCS region (required, e.g. us-central1)
  --storage-class=CLASS   Default storage class (default: STANDARD)
  --versioning            Enable object versioning
  --no-lifecycle          Skip applying the default ML lifecycle policy
  -h, --help              Show this help

The default lifecycle policy:
  - checkpoints/temp/, experiments/temp/ → delete after 7 days
  - checkpoints/                        → NEARLINE after 30 days
  - experiments/                        → COLDLINE after 90 days
  - logs/                               → delete after 365 days
EOF
    exit 1
}

BUCKET_NAME=""
LOCATION=""
STORAGE_CLASS="STANDARD"
ENABLE_VERSIONING=false
ENABLE_LIFECYCLE=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --location=*)       LOCATION="${1#*=}"; shift ;;
        --storage-class=*)  STORAGE_CLASS="${1#*=}"; shift ;;
        --versioning)       ENABLE_VERSIONING=true; shift ;;
        --no-lifecycle)     ENABLE_LIFECYCLE=false; shift ;;
        -h|--help)          usage ;;
        -*)                 echo "Error: unknown option $1" >&2; usage ;;
        *)
            if [[ -z "$BUCKET_NAME" ]]; then
                BUCKET_NAME="$1"
            fi
            shift ;;
    esac
done

[[ -z "$BUCKET_NAME" ]] && { echo "Error: bucket-name is required" >&2; usage; }
[[ -z "$LOCATION" ]]    && { echo "Error: --location is required" >&2; usage; }

echo "Creating GCS bucket: gs://$BUCKET_NAME" >&2

if gcloud storage buckets describe "gs://$BUCKET_NAME" &>/dev/null; then
    echo "Bucket gs://$BUCKET_NAME already exists — updating settings" >&2
else
    gcloud storage buckets create "gs://$BUCKET_NAME" \
        --location="$LOCATION" \
        --default-storage-class="$STORAGE_CLASS" \
        --uniform-bucket-level-access
fi

if [[ "$ENABLE_VERSIONING" == true ]]; then
    echo "Enabling object versioning" >&2
    gcloud storage buckets update "gs://$BUCKET_NAME" --versioning
fi

if [[ "$ENABLE_LIFECYCLE" == true ]]; then
    echo "Applying ML lifecycle policy" >&2
    LIFECYCLE_FILE=$(mktemp)
    cat > "$LIFECYCLE_FILE" << 'POLICY'
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"age": 7, "matchesPrefix": ["checkpoints/temp/", "experiments/temp/"]}
      },
      {
        "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
        "condition": {"age": 30, "matchesPrefix": ["checkpoints/"]}
      },
      {
        "action": {"type": "SetStorageClass", "storageClass": "COLDLINE"},
        "condition": {"age": 90, "matchesPrefix": ["experiments/"]}
      },
      {
        "action": {"type": "Delete"},
        "condition": {"age": 365, "matchesPrefix": ["logs/"]}
      }
    ]
  }
}
POLICY
    gcloud storage buckets update "gs://$BUCKET_NAME" --lifecycle-file="$LIFECYCLE_FILE"
    rm -f "$LIFECYCLE_FILE"
fi

echo "" >&2
echo "Bucket ready: gs://$BUCKET_NAME" >&2
echo "Console: https://console.cloud.google.com/storage/browser/$BUCKET_NAME" >&2
