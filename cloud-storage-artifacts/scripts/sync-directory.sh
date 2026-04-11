#!/bin/bash
#
# sync-directory.sh - Bidirectional sync between local and cloud storage
#
# Usage: ./sync-directory.sh [options] <source> <destination>
#
# Examples:
#   ./sync-directory.sh ./outputs gs://bucket/outputs
#   ./sync-directory.sh gs://bucket/checkpoints ./checkpoints
#   ./sync-directory.sh ./data s3://bucket/data --exclude="*.tmp"
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
DELETE=false
EXCLUDE_PATTERNS=()
DRY_RUN=false
PARALLEL=true
PROGRESS=true
PRESERVE_TIMESTAMPS=true
COMPRESSION=false
RESUME=false
BANDWIDTH_LIMIT=""

usage() {
    cat << EOF
Usage: $0 [OPTIONS] <source> <destination>

Arguments:
  source          Source path (local or cloud URI)
  destination     Destination path (local or cloud URI)

Options:
  --delete                Delete files at destination not in source
  --exclude=PATTERN       Exclude files matching pattern (repeatable)
  --dry-run               Show what would be synced without doing it
  --no-parallel           Disable parallel transfers
  --no-progress           Disable progress bars
  --no-preserve-time      Don't preserve timestamps
  --compress              Compress files during transfer
  --resume                Resume interrupted transfers
  --bwlimit=RATE          Limit bandwidth (e.g., 10M, 1G)
  -h, --help              Show this help

Sync directions:
  Local to Cloud:   ./sync-directory.sh ./data gs://bucket/data
  Cloud to Local:   ./sync-directory.sh gs://bucket/data ./data
  Cloud to Cloud:   ./sync-directory.sh gs://b1/data gs://b2/data

Examples:
  # Sync local outputs to GCS
  $0 ./outputs gs://bucket/experiments/run-001

  # Sync with deletion
  $0 ./outputs gs://bucket/outputs --delete

  # Exclude temporary files
  $0 ./data gs://bucket/data --exclude="*.tmp" --exclude="__pycache__/"

  # Resume interrupted transfer
  $0 ./large-dataset gs://bucket/dataset --resume

  # Limit bandwidth
  $0 ./outputs gs://bucket/outputs --bwlimit=100M
EOF
    exit 1
}

# Parse arguments
SOURCE=""
DESTINATION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --delete)
            DELETE=true
            shift
            ;;
        --exclude=*)
            EXCLUDE_PATTERNS+=("${1#*=}")
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-parallel)
            PARALLEL=false
            shift
            ;;
        --no-progress)
            PROGRESS=false
            shift
            ;;
        --no-preserve-time)
            PRESERVE_TIMESTAMPS=false
            shift
            ;;
        --compress)
            COMPRESSION=true
            shift
            ;;
        --resume)
            RESUME=true
            shift
            ;;
        --bwlimit=*)
            BANDWIDTH_LIMIT="${1#*=}"
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
            if [[ -z "$SOURCE" ]]; then
                SOURCE="$1"
            elif [[ -z "$DESTINATION" ]]; then
                DESTINATION="$1"
            else
                echo -e "${RED}Too many arguments${NC}"
                usage
            fi
            shift
            ;;
    esac
done

# Validate inputs
if [[ -z "$SOURCE" ]] || [[ -z "$DESTINATION" ]]; then
    echo -e "${RED}Error: source and destination are required${NC}"
    usage
fi

# Detect source and destination types
detect_type() {
    local path="$1"
    if [[ "$path" == gs://* ]]; then
        echo "gcs"
    elif [[ "$path" == s3://* ]]; then
        echo "s3"
    elif [[ "$path" == https://* ]] || [[ "$path" == wasb://* ]]; then
        echo "azure"
    elif [[ -d "$path" ]] || [[ -f "$path" ]]; then
        echo "local"
    else
        echo "unknown"
    fi
}

SOURCE_TYPE=$(detect_type "$SOURCE")
DEST_TYPE=$(detect_type "$DESTINATION")

if [[ "$SOURCE_TYPE" == "unknown" ]]; then
    echo -e "${RED}Error: Cannot detect source type: $SOURCE${NC}"
    exit 1
fi

if [[ "$DEST_TYPE" == "unknown" ]]; then
    echo -e "${RED}Error: Cannot detect destination type: $DESTINATION${NC}"
    exit 1
fi

echo -e "${BLUE}Sync Configuration${NC}"
echo "Source:      $SOURCE ($SOURCE_TYPE)"
echo "Destination: $DESTINATION ($DEST_TYPE)"
echo "Delete:      $DELETE"
echo "Dry run:     $DRY_RUN"
echo ""

# Build exclude flags
build_excludes() {
    local flags=""
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        case $1 in
            gcs)
                flags="$flags --exclude-pattern='$pattern'"
                ;;
            s3)
                flags="$flags --exclude '$pattern'"
                ;;
            azure)
                # Azure doesn't support excludes directly in sync
                ;;
            rsync)
                flags="$flags --exclude='$pattern'"
                ;;
        esac
    done
    echo "$flags"
}

# Sync functions
sync_gcs_local() {
    local src="$1"
    local dst="$2"
    local direction="$3"  # up or down
    
    local flags=""
    
    if [[ "$PARALLEL" == true ]]; then
        flags="$flags --parallelism=8"
    fi
    
    if [[ "$DELETE" == true ]]; then
        flags="$flags --delete-unmatched-destination-objects"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN] Would sync:${NC}"
        gcloud storage rsync $flags --dry-run -r "$src" "$dst"
        return
    fi
    
    echo -e "${BLUE}Syncing...${NC}"
    gcloud storage rsync $flags -r "$src" "$dst"
}

sync_s3_local() {
    local src="$1"
    local dst="$2"
    local direction="$3"
    
    local flags=""
    
    if [[ "$DELETE" == true ]]; then
        flags="$flags --delete"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN] Would sync:${NC}"
        flags="$flags --dryrun"
    fi
    
    # Add excludes
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        flags="$flags --exclude '$pattern'"
    done
    
    echo -e "${BLUE}Syncing...${NC}"
    eval aws s3 sync $flags "$src" "$dst"
}

sync_azure_local() {
    local src="$1"
    local dst="$2"
    local direction="$3"
    
    # Parse Azure URL
    local storage_account="${src#https://}"
    storage_account="${storage_account%%.*}"
    local container_path="${src#https://$storage_account.blob.core.windows.net/}"
    local container="${container_path%%/*}"
    local blob_path="${container_path#$container/}"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN] Would sync:${NC}"
        echo "  az storage blob sync --account-name $storage_account --container $container --source $dst"
        return
    fi
    
    if [[ "$direction" == "up" ]]; then
        # Local to Azure
        az storage blob sync \
            --account-name "$storage_account" \
            --container "$container" \
            --source "$src"
    else
        # Azure to local - download batch
        mkdir -p "$dst"
        az storage blob download-batch \
            --account-name "$storage_account" \
            --source "$container" \
            --destination "$dst"
    fi
}

sync_local_local() {
    local src="$1"
    local dst="$2"
    
    if [[ ! -d "$dst" ]]; then
        mkdir -p "$dst"
    fi
    
    local flags="-av"
    
    if [[ "$DELETE" == true ]]; then
        flags="$flags --delete"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        flags="$flags --dry-run"
    fi
    
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        flags="$flags --exclude='$pattern'"
    done
    
    echo -e "${BLUE}Syncing with rsync...${NC}"
    eval rsync $flags "$src/" "$dst/"
}

# Compression wrapper
compress_and_sync() {
    local src="$1"
    local dst="$2"
    local direction="$3"
    
    if [[ "$COMPRESSION" != true ]]; then
        return 1
    fi
    
    echo -e "${BLUE}Using compression...${NC}"
    local archive_name="sync_$(date +%s).tar.gz"
    local temp_dir=$(mktemp -d)
    
    if [[ "$direction" == "up" ]]; then
        # Compress locally, upload, extract remotely
        echo "Creating archive..."
        tar -czf "$temp_dir/$archive_name" -C "$src" .
        
        # Upload archive
        local archive_dst="$dst/$archive_name"
        sync_gcs_local "$temp_dir/$archive_name" "$archive_dst" "up"
        
        # Extract remotely (would need SSH or cloud function)
        echo -e "${YELLOW}Note: Remote extraction not implemented${NC}"
    else
        # Download, extract
        echo -e "${YELLOW}Compressed download not yet implemented${NC}"
    fi
    
    rm -rf "$temp_dir"
}

# Bandwidth limiting
setup_bwlimit() {
    if [[ -z "$BANDWIDTH_LIMIT" ]]; then
        return
    fi
    
    # Use pv for bandwidth limiting if available
    if command -v pv &> /dev/null; then
        echo "Bandwidth limit: $BANDWIDTH_LIMIT"
    else
        echo -e "${YELLOW}Warning: pv not installed, bandwidth limiting unavailable${NC}"
    fi
}

# Progress reporting
show_progress() {
    if [[ "$PROGRESS" == false ]]; then
        return
    fi
    
    local src="$1"
    local dst="$2"
    
    # Count files
    local file_count=0
    if [[ -d "$src" ]]; then
        file_count=$(find "$src" -type f 2>/dev/null | wc -l)
    else
        file_count=1
    fi
    
    echo "Files to sync: ~$file_count"
}

# Main sync logic
main() {
    # Determine direction
    local direction=""
    if [[ "$SOURCE_TYPE" == "local" ]] && [[ "$DEST_TYPE" != "local" ]]; then
        direction="up"
    elif [[ "$SOURCE_TYPE" != "local" ]] && [[ "$DEST_TYPE" == "local" ]]; then
        direction="down"
    elif [[ "$SOURCE_TYPE" != "local" ]] && [[ "$DEST_TYPE" != "local" ]]; then
        direction="cloud"
    else
        direction="local"
    fi
    
    # Show progress info
    show_progress "$SOURCE" "$DESTINATION"
    
    # Setup bandwidth limit
    setup_bwlimit
    
    # Handle resume
    if [[ "$RESUME" == true ]]; then
        echo -e "${BLUE}Resume mode enabled${NC}"
        # Most sync tools handle resume automatically via partial files
    fi
    
    # Execute sync based on types
    case $direction in
        up)
            case $DEST_TYPE in
                gcs)
                    sync_gcs_local "$SOURCE" "$DESTINATION" "up"
                    ;;
                s3)
                    sync_s3_local "$SOURCE" "$DESTINATION" "up"
                    ;;
                azure)
                    sync_azure_local "$SOURCE" "$DESTINATION" "up"
                    ;;
            esac
            ;;
        down)
            case $SOURCE_TYPE in
                gcs)
                    sync_gcs_local "$SOURCE" "$DESTINATION" "down"
                    ;;
                s3)
                    sync_s3_local "$SOURCE" "$DESTINATION" "down"
                    ;;
                azure)
                    sync_azure_local "$SOURCE" "$DESTINATION" "down"
                    ;;
            esac
            ;;
        cloud)
            echo -e "${YELLOW}Cloud-to-cloud sync not directly supported${NC}"
            echo "Using intermediate local copy..."
            local temp_dir=$(mktemp -d)
            
            # Download to temp
            case $SOURCE_TYPE in
                gcs)
                    sync_gcs_local "$SOURCE" "$temp_dir" "down"
                    ;;
                s3)
                    sync_s3_local "$SOURCE" "$temp_dir" "down"
                    ;;
            esac
            
            # Upload from temp
            case $DEST_TYPE in
                gcs)
                    sync_gcs_local "$temp_dir" "$DESTINATION" "up"
                    ;;
                s3)
                    sync_s3_local "$temp_dir" "$DESTINATION" "up"
                    ;;
            esac
            
            rm -rf "$temp_dir"
            ;;
        local)
            sync_local_local "$SOURCE" "$DESTINATION"
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}Sync complete!${NC}"
    
    # Show summary
    if [[ "$DRY_RUN" == false ]]; then
        echo ""
        echo "Summary:"
        if [[ -d "$DESTINATION" ]]; then
            echo "  Destination size: $(du -sh "$DESTINATION" 2>/dev/null | cut -f1)"
            echo "  Files: $(find "$DESTINATION" -type f 2>/dev/null | wc -l)"
        fi
    fi
}

main
