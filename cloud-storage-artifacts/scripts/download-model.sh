#!/bin/bash
#
# download-model.sh - Download ML models with validation and caching
#
# Usage: ./download-model.sh [options] <remote-uri> [local-path]
#
# Examples:
#   ./download-model.sh gs://bucket/models/llama-7b ./models/
#   ./download-model.sh --verify s3://bucket/models/model.pt ./models/model.pt
#   ./download-model.sh --cache-dir=/cache gs://bucket/models/gpt2 ./models/gpt2
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
VERIFY=false
CHECKSUM=""
CACHE_DIR="${ML_CACHE_DIR:-$HOME/.cache/ml-models}"
FORCE=false
EXTRACT=false
DRY_RUN=false
PROGRESS=true

usage() {
    cat << EOF
Usage: $0 [OPTIONS] <remote-uri> [local-path]

Arguments:
  remote-uri      Source URI (gs://, s3://, https://, or HF repo)
  local-path      Destination path (default: current directory)

Options:
  --verify                Verify checksum after download
  --checksum=HASH         Expected MD5/SHA256 checksum
  --cache-dir=DIR         Cache directory (default: ~/.cache/ml-models)
  --force                 Overwrite existing files
  --extract               Extract archives after download
  --no-progress           Disable progress bar
  --dry-run               Show what would be downloaded
  -h, --help              Show this help

Examples:
  # Download from GCS
  $0 gs://bucket/models/llama-7b ./models/llama-7b

  # Download specific file with verification
  $0 --verify --checksum=abc123 gs://bucket/model.pt ./model.pt

  # Download from HuggingFace
  $0 meta-llama/Llama-2-7b-hf ./models/llama-2-7b

  # Use cache
  $0 --cache-dir=/shared/cache gs://bucket/large-model ./models/
EOF
    exit 1
}

# Parse arguments
REMOTE_URI=""
LOCAL_PATH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --verify)
            VERIFY=true
            shift
            ;;
        --checksum=*)
            CHECKSUM="${1#*=}"
            shift
            ;;
        --cache-dir=*)
            CACHE_DIR="${1#*=}"
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --extract)
            EXTRACT=true
            shift
            ;;
        --no-progress)
            PROGRESS=false
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
            if [[ -z "$REMOTE_URI" ]]; then
                REMOTE_URI="$1"
            elif [[ -z "$LOCAL_PATH" ]]; then
                LOCAL_PATH="$1"
            else
                echo -e "${RED}Too many arguments${NC}"
                usage
            fi
            shift
            ;;
    esac
done

# Validate inputs
if [[ -z "$REMOTE_URI" ]]; then
    echo -e "${RED}Error: remote-uri is required${NC}"
    usage
fi

# Set default local path
if [[ -z "$LOCAL_PATH" ]]; then
    LOCAL_PATH="$(basename "$REMOTE_URI")"
fi

# Detect provider
PROVIDER=""
if [[ "$REMOTE_URI" == gs://* ]]; then
    PROVIDER="gcs"
elif [[ "$REMOTE_URI" == s3://* ]]; then
    PROVIDER="s3"
elif [[ "$REMOTE_URI" == https://*.blob.core.windows.net* ]]; then
    PROVIDER="azure"
elif [[ "$REMOTE_URI" == hf://* ]] || [[ "$REMOTE_URI" == */* && ! "$REMOTE_URI" =~ ^(gs|s3|https):// ]]; then
    # HuggingFace format: org/model or hf://org/model
    PROVIDER="huggingface"
    REMOTE_URI="${REMOTE_URI#hf://}"
else
    echo -e "${RED}Error: Unsupported URI: $REMOTE_URI${NC}"
    exit 1
fi

echo -e "${BLUE}Downloading from $PROVIDER${NC}"
echo "Source: $REMOTE_URI"
echo "Destination: $LOCAL_PATH"
echo "Cache: $CACHE_DIR"

# Create directories
mkdir -p "$CACHE_DIR"
mkdir -p "$(dirname "$LOCAL_PATH")"

# Calculate cache key
calculate_cache_key() {
    local uri="$1"
    # Use URI hash + modification time (if available)
    echo -n "$uri" | md5sum | cut -d' ' -f1
}

# Check cache
check_cache() {
    local uri="$1"
    local cache_key=$(calculate_cache_key "$uri")
    local cache_meta="$CACHE_DIR/$cache_key.meta"
    local cache_data="$CACHE_DIR/$cache_key.data"
    
    if [[ -f "$cache_meta" ]] && [[ -f "$cache_data" ]]; then
        local cached_uri=$(cat "$cache_meta" 2>/dev/null)
        if [[ "$cached_uri" == "$uri" ]]; then
            echo "$cache_data"
            return 0
        fi
    fi
    return 1
}

# Update cache
update_cache() {
    local uri="$1"
    local source="$2"
    local cache_key=$(calculate_cache_key "$uri")
    local cache_meta="$CACHE_DIR/$cache_key.meta"
    local cache_data="$CACHE_DIR/$cache_key.data"
    
    cp -r "$source" "$cache_data"
    echo "$uri" > "$cache_meta"
}

# Download functions
download_gcs() {
    local src="$1"
    local dst="$2"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN] Would download:${NC}"
        echo "  gcloud storage cp -r $src $dst"
        return 0
    fi
    
    if [[ "$PROGRESS" == true ]]; then
        gcloud storage cp -r "$src" "$dst"
    else
        gcloud storage cp -r "$src" "$dst" 2>/dev/null
    fi
}

download_s3() {
    local src="$1"
    local dst="$2"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN] Would download:${NC}"
        echo "  aws s3 cp --recursive $src $dst"
        return 0
    fi
    
    local flags=""
    if [[ "$PROGRESS" == true ]]; then
        flags="--no-progress"
    fi
    
    if aws s3 ls "$src" &>/dev/null; then
        # It's a directory
        aws s3 cp $flags --recursive "$src" "$dst"
    else
        # It's a file
        aws s3 cp $flags "$src" "$dst"
    fi
}

download_azure() {
    local src="$1"
    local dst="$2"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN] Would download:${NC}"
        echo "  az storage blob download-batch ..."
        return 0
    fi
    
    # Parse URL
    local storage_account="${src#https://}"
    storage_account="${storage_account%%.*}"
    local container_path="${src#https://$storage_account.blob.core.windows.net/}"
    local container="${container_path%%/*}"
    local blob_path="${container_path#$container/}"
    
    mkdir -p "$dst"
    az storage blob download-batch \
        --account-name "$storage_account" \
        --source "$container" \
        --pattern "$blob_path/*" \
        --destination "$dst"
}

download_huggingface() {
    local repo="$1"
    local dst="$2"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN] Would download:${NC}"
        echo "  huggingface-cli download $repo"
        return 0
    fi
    
    # Check for huggingface_hub
    if ! python3 -c "import huggingface_hub" 2>/dev/null; then
        echo -e "${YELLOW}Installing huggingface_hub...${NC}"
        pip install -q huggingface_hub
    fi
    
    python3 << PYEOF
from huggingface_hub import snapshot_download
import os

repo_id = "$repo"
local_dir = "$dst"
cache_dir = "$CACHE_DIR/hf"

os.makedirs(local_dir, exist_ok=True)
os.makedirs(cache_dir, exist_ok=True)

snapshot_download(
    repo_id=repo_id,
    local_dir=local_dir,
    cache_dir=cache_dir,
    local_dir_use_symlinks=False
)
PYEOF
}

# Verify checksum
verify_checksum() {
    local file="$1"
    local expected="$2"
    
    echo -e "${BLUE}Verifying checksum...${NC}"
    
    local actual
    if [[ ${#expected} -eq 32 ]]; then
        # MD5
        actual=$(md5sum "$file" | cut -d' ' -f1)
    else
        # SHA256
        actual=$(sha256sum "$file" | cut -d' ' -f1)
    fi
    
    if [[ "$actual" == "$expected" ]]; then
        echo -e "${GREEN}Checksum verified: $actual${NC}"
        return 0
    else
        echo -e "${RED}Checksum mismatch!${NC}"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        return 1
    fi
}

# Extract archive
extract_archive() {
    local file="$1"
    local dst="$2"
    
    echo -e "${BLUE}Extracting archive...${NC}"
    
    case "$file" in
        *.tar.gz|*.tgz)
            tar -xzf "$file" -C "$dst"
            ;;
        *.tar.bz2)
            tar -xjf "$file" -C "$dst"
            ;;
        *.tar.xz)
            tar -xJf "$file" -C "$dst"
            ;;
        *.zip)
            unzip -q "$file" -d "$dst"
            ;;
        *)
            echo -e "${YELLOW}Unknown archive format: $file${NC}"
            return 1
            ;;
    esac
    
    echo -e "${GREEN}Extracted to: $dst${NC}"
}

# Main download logic
main() {
    # Check if destination exists
    if [[ -e "$LOCAL_PATH" ]] && [[ "$FORCE" == false ]]; then
        echo -e "${YELLOW}Destination already exists: $LOCAL_PATH${NC}"
        read -p "Overwrite? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            exit 0
        fi
    fi
    
    # Check cache first
    if [[ "$FORCE" == false ]]; then
        local cached_file=$(check_cache "$REMOTE_URI")
        if [[ -n "$cached_file" ]]; then
            echo -e "${GREEN}Found in cache!${NC}"
            cp -r "$cached_file" "$LOCAL_PATH"
            echo -e "${GREEN}Copied from cache to: $LOCAL_PATH${NC}"
            return 0
        fi
    fi
    
    # Download based on provider
    local temp_dir=$(mktemp -d)
    local download_dest="$temp_dir/download"
    
    case $PROVIDER in
        gcs)
            download_gcs "$REMOTE_URI" "$download_dest"
            ;;
        s3)
            download_s3 "$REMOTE_URI" "$download_dest"
            ;;
        azure)
            download_azure "$REMOTE_URI" "$download_dest"
            ;;
        huggingface)
            download_huggingface "$REMOTE_URI" "$download_dest"
            ;;
    esac
    
    if [[ "$DRY_RUN" == true ]]; then
        rm -rf "$temp_dir"
        return 0
    fi
    
    # Verify checksum if provided
    if [[ -n "$CHECKSUM" ]]; then
        if [[ -f "$download_dest" ]]; then
            verify_checksum "$download_dest" "$CHECKSUM" || {
                rm -rf "$temp_dir"
                exit 1
            }
        fi
    fi
    
    # Move to final destination
    if [[ -e "$LOCAL_PATH" ]]; then
        rm -rf "$LOCAL_PATH"
    fi
    mv "$download_dest" "$LOCAL_PATH"
    
    # Update cache
    update_cache "$REMOTE_URI" "$LOCAL_PATH"
    
    # Extract if requested
    if [[ "$EXTRACT" == true ]]; then
        if [[ -f "$LOCAL_PATH" ]]; then
            extract_archive "$LOCAL_PATH" "$(dirname "$LOCAL_PATH")"
        fi
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    echo -e "${GREEN}Download complete: $LOCAL_PATH${NC}"
    
    # Show size
    local size=$(du -sh "$LOCAL_PATH" 2>/dev/null | cut -f1)
    echo "Size: $size"
}

main
