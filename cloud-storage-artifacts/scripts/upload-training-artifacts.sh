#!/bin/bash
# Purpose: Upload ML training artifacts to GCS with metadata tagging
# Usage:   ./upload-training-artifacts.sh <local-path> <gs://uri>
#
# Examples:
#   ./upload-training-artifacts.sh ./outputs gs://bucket/experiments/run-001
#   ./upload-training-artifacts.sh --compress ./checkpoints gs://bucket/checkpoints/run-001.tar.gz
#   ./upload-training-artifacts.sh --dry-run ./outputs gs://bucket/experiments/run-001

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat >&2 << 'EOF'
Usage: upload-training-artifacts.sh [options] <local-path> <gs://uri>

Arguments:
  local-path        Local file or directory to upload
  gs://uri          Destination GCS URI

Options:
  --compress            Compress into tar.gz before upload
  --storage-class=CLASS Override storage class (STANDARD, NEARLINE, etc.)
  --dry-run             Show what would be uploaded
  -h, --help            Show this help

Automatically attaches metadata: git commit, branch, timestamp, hostname.
EOF
    exit 1
}

COMPRESS=false
STORAGE_CLASS=""
DRY_RUN=false
LOCAL_PATH=""
GCS_URI=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --compress)         COMPRESS=true; shift ;;
        --storage-class=*)  STORAGE_CLASS="${1#*=}"; shift ;;
        --dry-run)          DRY_RUN=true; shift ;;
        -h|--help)          usage ;;
        -*)                 echo "Error: unknown option $1" >&2; usage ;;
        *)
            if [[ -z "$LOCAL_PATH" ]]; then
                LOCAL_PATH="$1"
            elif [[ -z "$GCS_URI" ]]; then
                GCS_URI="$1"
            else
                echo "Error: too many arguments" >&2; usage
            fi
            shift ;;
    esac
done

[[ -z "$LOCAL_PATH" ]] || [[ -z "$GCS_URI" ]] && { echo "Error: local-path and gs://uri are required" >&2; usage; }
[[ ! -e "$LOCAL_PATH" ]] && { echo "Error: path does not exist: $LOCAL_PATH" >&2; exit 1; }
[[ "$GCS_URI" != gs://* ]] && { echo "Error: destination must start with gs://" >&2; exit 1; }

# Build metadata flags
META_FLAGS=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    META_FLAGS="$META_FLAGS --custom-metadata=git-commit=$(git rev-parse --short HEAD)"
    META_FLAGS="$META_FLAGS --custom-metadata=git-branch=$(git rev-parse --abbrev-ref HEAD)"
fi
META_FLAGS="$META_FLAGS --custom-metadata=upload-time=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
META_FLAGS="$META_FLAGS --custom-metadata=upload-host=$(hostname)"

CP_FLAGS=""
[[ -n "$STORAGE_CLASS" ]] && CP_FLAGS="$CP_FLAGS --storage-class=$STORAGE_CLASS"

# Handle compression
UPLOAD_PATH="$LOCAL_PATH"
CLEANUP_FILE=""
if [[ "$COMPRESS" == true ]]; then
    echo "Compressing $LOCAL_PATH..." >&2
    CLEANUP_FILE=$(mktemp --suffix=.tar.gz)
    tar -czf "$CLEANUP_FILE" -C "$(dirname "$LOCAL_PATH")" "$(basename "$LOCAL_PATH")"
    UPLOAD_PATH="$CLEANUP_FILE"
fi

if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY RUN] Would upload: $UPLOAD_PATH → $GCS_URI" >&2
    [[ -n "$CLEANUP_FILE" ]] && rm -f "$CLEANUP_FILE"
    exit 0
fi

echo "Uploading $UPLOAD_PATH → $GCS_URI" >&2
if [[ -d "$UPLOAD_PATH" ]]; then
    # shellcheck disable=SC2086
    gcloud storage cp $CP_FLAGS $META_FLAGS -r "$UPLOAD_PATH" "$GCS_URI"
else
    # shellcheck disable=SC2086
    gcloud storage cp $CP_FLAGS $META_FLAGS "$UPLOAD_PATH" "$GCS_URI"
fi

[[ -n "$CLEANUP_FILE" ]] && rm -f "$CLEANUP_FILE"

echo "Upload complete. Verify:" >&2
echo "  gcloud storage ls -r $GCS_URI" >&2
