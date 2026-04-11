#!/bin/bash
#
# upload-training-artifacts.sh - Upload ML training artifacts with metadata
#
# Usage: ./upload-training-artifacts.sh [options] <local-path> <remote-uri>
#
# Examples:
#   ./upload-training-artifacts.sh ./outputs gs://bucket/experiments/run-001
#   ./upload-training-artifacts.sh --metadata=experiment.json ./checkpoints gs://bucket/checkpoints/run-001
#   ./upload-training-artifacts.sh --compress ./model gs://bucket/models/v1.0
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
COMPRESS=false
METADATA_FILE=""
DRY_RUN=false
EXCLUDE_PATTERNS=""
STORAGE_CLASS=""
CONTENT_TYPE=""
PARALLEL=true
METADATA=()

usage() {
    cat << EOF
Usage: $0 [OPTIONS] <local-path> <remote-uri>

Arguments:
  local-path      Local directory or file to upload
  remote-uri      Destination URI (gs://, s3://, or https://)

Options:
  --metadata=FILE         JSON file with metadata to attach
  --meta-key=VALUE        Add key=value metadata (can specify multiple)
  --compress              Compress files before upload (tar.gz)
  --storage-class=CLASS   Set storage class (STANDARD, NEARLINE, etc.)
  --content-type=TYPE     Set content type
  --exclude=PATTERN       Exclude files matching pattern
  --no-parallel           Disable parallel uploads
  --dry-run               Show what would be uploaded without doing it
  -h, --help              Show this help

Examples:
  # Basic upload
  $0 ./outputs gs://bucket/experiments/run-001

  # With metadata
  $0 --meta-run-id=123 --meta-model=llama-7b ./outputs gs://bucket/experiments/run-001

  # Compress directory
  $0 --compress ./checkpoints gs://bucket/checkpoints/run-001.tar.gz

  # Dry run
  $0 --dry-run ./outputs gs://bucket/experiments/run-001
EOF
    exit 1
}

# Parse arguments
LOCAL_PATH=""
REMOTE_URI=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --metadata=*)
            METADATA_FILE="${1#*=}"
            shift
            ;;
        --meta-*=*)
            METADATA+=("${1#--meta-}")
            shift
            ;;
        --compress)
            COMPRESS=true
            shift
            ;;
        --storage-class=*)
            STORAGE_CLASS="${1#*=}"
            shift
            ;;
        --content-type=*)
            CONTENT_TYPE="${1#*=}"
            shift
            ;;
        --exclude=*)
            EXCLUDE_PATTERNS="${1#*=}"
            shift
            ;;
        --no-parallel)
            PARALLEL=false
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
        *)
            if [[ -z "$LOCAL_PATH" ]]; then
                LOCAL_PATH="$1"
            elif [[ -z "$REMOTE_URI" ]]; then
                REMOTE_URI="$1"
            else
                echo -e "${RED}Too many arguments${NC}"
                usage
            fi
            shift
            ;;
    esac
done

# Validate inputs
if [[ -z "$LOCAL_PATH" ]] || [[ -z "$REMOTE_URI" ]]; then
    echo -e "${RED}Error: local-path and remote-uri are required${NC}"
    usage
fi

if [[ ! -e "$LOCAL_PATH" ]]; then
    echo -e "${RED}Error: Local path does not exist: $LOCAL_PATH${NC}"
    exit 1
fi

# Detect provider
PROVIDER=""
if [[ "$REMOTE_URI" == gs://* ]]; then
    PROVIDER="gcs"
elif [[ "$REMOTE_URI" == s3://* ]]; then
    PROVIDER="s3"
elif [[ "$REMOTE_URI" == https://* ]] || [[ "$REMOTE_URI" == wasb://* ]]; then
    PROVIDER="azure"
else
    echo -e "${RED}Error: Unsupported remote URI: $REMOTE_URI${NC}"
    echo "Supported: gs://, s3://, https:// (Azure)"
    exit 1
fi

echo -e "${BLUE}Uploading to $PROVIDER${NC}"
echo "Source: $LOCAL_PATH"
echo "Destination: $REMOTE_URI"

# Build metadata
build_metadata() {
    local metadata_args=()
    
    # Add git info if available
    if git rev-parse --git-dir > /dev/null 2>&1; then
        metadata_args+=("git-commit=$(git rev-parse --short HEAD)")
        metadata_args+=("git-branch=$(git rev-parse --abbrev-ref HEAD)")
    fi
    
    # Add timestamp
    metadata_args+=("upload-time=$(date -u +%Y-%m-%dT%H:%M:%SZ)")
    metadata_args+=("upload-host=$(hostname)")
    metadata_args+=("upload-user=$(whoami)")
    
    # Add custom metadata from file
    if [[ -n "$METADATA_FILE" ]] && [[ -f "$METADATA_FILE" ]]; then
        while IFS='=' read -r key value; do
            metadata_args+=("$key=$value")
        done < <(jq -r 'to_entries | .[] | "\(.key)=\(.value)"' "$METADATA_FILE" 2>/dev/null || true)
    fi
    
    # Add command-line metadata
    metadata_args+=("${METADATA[@]}")
    
    echo "${metadata_args[@]}"
}

# Upload functions
upload_gcs() {
    local src="$1"
    local dst="$2"
    local flags=""
    
    if [[ "$PARALLEL" == true ]]; then
        flags="--parallelism=8"
    fi
    
    if [[ -n "$STORAGE_CLASS" ]]; then
        flags="$flags --storage-class=$STORAGE_CLASS"
    fi
    
    if [[ -n "$CONTENT_TYPE" ]]; then
        flags="$flags --content-type=$CONTENT_TYPE"
    fi
    
    # Build metadata flags
    local meta_flags=""
    for meta in $(build_metadata); do
        meta_flags="$meta_flags --custom-metadata=$meta"
    done
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN] Would upload:${NC}"
        echo "  gcloud storage cp $flags $meta_flags -r $src $dst"
        return
    fi
    
    if [[ -d "$src" ]]; then
        gcloud storage cp $flags $meta_flags -r "$src" "$dst"
    else
        gcloud storage cp $flags $meta_flags "$src" "$dst"
    fi
}

upload_s3() {
    local src="$1"
    local dst="$2"
    local flags=""
    
    if [[ -n "$STORAGE_CLASS" ]]; then
        flags="$flags --storage-class $STORAGE_CLASS"
    fi
    
    if [[ -n "$CONTENT_TYPE" ]]; then
        flags="$flags --content-type $CONTENT_TYPE"
    fi
    
    if [[ -n "$EXCLUDE_PATTERNS" ]]; then
        flags="$flags --exclude $EXCLUDE_PATTERNS"
    fi
    
    # Build metadata
    local metadata_args=()
    for meta in $(build_metadata); do
        metadata_args+=("--metadata" "$meta")
    done
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN] Would upload:${NC}"
        echo "  aws s3 cp $flags $src $dst"
        return
    fi
    
    if [[ -d "$src" ]]; then
        aws s3 cp $flags --recursive "$src" "$dst"
    else
        aws s3 cp $flags "$src" "$dst"
    fi
    
    # Apply metadata separately for S3
    # (AWS CLI cp doesn't support inline metadata well)
}

upload_azure() {
    local src="$1"
    local dst="$2"
    
    # Parse Azure URL
    local account_container_path="${dst#https://}"
    account_container_path="${account_container_path%.blob.core.windows.net/*}"
    local storage_account="${account_container_path%%.*}"
    
    # Extract container and blob path
    local container_path="${dst#https://$storage_account.blob.core.windows.net/}"
    local container="${container_path%%/*}"
    local blob_path="${container_path#$container/}"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN] Would upload:${NC}"
        echo "  az storage blob upload-batch --account-name $storage_account --destination $container --source $src"
        return
    fi
    
    if [[ -d "$src" ]]; then
        az storage blob upload-batch \
            --account-name "$storage_account" \
            --destination "$container" \
            --destination-path "$blob_path" \
            --source "$src"
    else
        az storage blob upload \
            --account-name "$storage_account" \
            --container-name "$container" \
            --name "$blob_path" \
            --file "$src"
    fi
}

# Handle compression
if [[ "$COMPRESS" == true ]]; then
    echo -e "${BLUE}Compressing files...${NC}"
    COMPRESSED_FILE="/tmp/$(basename "$LOCAL_PATH").$(date +%s).tar.gz"
    tar -czf "$COMPRESSED_FILE" -C "$(dirname "$LOCAL_PATH")" "$(basename "$LOCAL_PATH")"
    LOCAL_PATH="$COMPRESSED_FILE"
    
    # Adjust destination if it's a directory path
    if [[ "$REMOTE_URI" == */ ]]; then
        REMOTE_URI="${REMOTE_URI}$(basename "$COMPRESSED_FILE")"
    fi
fi

# Perform upload
echo -e "${BLUE}Starting upload...${NC}"

case $PROVIDER in
    gcs)
        upload_gcs "$LOCAL_PATH" "$REMOTE_URI"
        ;;
    s3)
        upload_s3 "$LOCAL_PATH" "$REMOTE_URI"
        ;;
    azure)
        upload_azure "$LOCAL_PATH" "$REMOTE_URI"
        ;;
esac

# Cleanup compressed file
if [[ "$COMPRESS" == true ]] && [[ -f "$COMPRESSED_FILE" ]]; then
    rm -f "$COMPRESSED_FILE"
fi

if [[ "$DRY_RUN" == false ]]; then
    echo -e "${GREEN}Upload complete!${NC}"
    echo "Verify with:"
    case $PROVIDER in
        gcs)
            echo "  gcloud storage ls -r $REMOTE_URI"
            ;;
        s3)
            echo "  aws s3 ls --recursive $REMOTE_URI"
            ;;
        azure)
            echo "  az storage blob list --account-name $storage_account --container-name $container"
            ;;
    esac
fi
