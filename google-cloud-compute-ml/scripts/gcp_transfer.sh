#!/bin/bash
#
# gcp_transfer.sh - Transfer files between local machine and GCP VMs
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DEFAULT_ZONE="us-central1-a"

show_help() {
    cat << EOF
Usage: $(basename "$0") <command> [options]

Commands:
  upload <local-path> <instance:remote-path>    Upload files to VM
  download <instance:remote-path> <local-path>  Download files from VM
  sync-up <local-dir> <gcs-bucket>              Sync directory to GCS
  sync-down <gcs-bucket> <local-dir>            Sync GCS to local

Options:
  --zone=<zone>                    Zone (default: $DEFAULT_ZONE)
  --project=<project>              GCP project ID
  --recurse                        Recursive transfer (for directories)

Examples:
  # Upload a file
  $(basename "$0") upload ./model.bin gemma-trainer:/home/\$USER/models/

  # Upload a directory
  $(basename "$0") upload ./data/ gemma-trainer:/home/\$USER/data/ --recurse

  # Download results
  $(basename "$0") download gemma-trainer:/home/\$USER/output/ ./results/

  # Sync large dataset via GCS (recommended for >1GB)
  $(basename "$0") sync-up ./big-dataset/ gs://my-bucket/datasets/

Notes:
  - Uses IAP tunneling for secure transfer
  - For files >1GB, use GCS sync (more reliable)
  - Remote paths must include instance name with colon: instance:/path

EOF
}

parse_opts() {
    ZONE="$DEFAULT_ZONE"
    PROJECT=""
    RECURSE=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --zone=*) ZONE="${1#*=}" ;;
            --project=*) PROJECT="${1#*=}" ;;
            --recurse) RECURSE="--recurse" ;;
            --) shift; break ;;
            --*) echo "Unknown option: $1"; exit 1 ;;
            *) break ;;
        esac
        shift
    done
}

build_scp_cmd() {
    local cmd="gcloud compute scp"
    [[ -n "$PROJECT" ]] && cmd="$cmd --project=$PROJECT"
    cmd="$cmd --zone=$ZONE"
    cmd="$cmd --tunnel-through-iap"
    [[ -n "$RECURSE" ]] && cmd="$cmd $RECURSE"
    echo "$cmd"
}

parse_remote_path() {
    local remote_path="$1"
    if [[ ! "$remote_path" =~ ^([^:]+):(.+)$ ]]; then
        echo -e "${RED}Error: Invalid remote path format${NC}"
        echo "Expected: instance-name:/path/to/file"
        exit 1
    fi
    INSTANCE="${BASH_REMATCH[1]}"
    REMOTE="${BASH_REMATCH[2]}"
}

cmd_upload() {
    local local_path="$1"
    local remote_spec="$2"
    
    [[ -z "$local_path" ]] && { echo -e "${RED}Error: Local path required${NC}"; exit 1; }
    [[ -z "$remote_spec" ]] && { echo -e "${RED}Error: Remote path required${NC}"; exit 1; }
    
    parse_remote_path "$remote_spec"
    
    if [[ ! -e "$local_path" ]]; then
        echo -e "${RED}Error: Local path does not exist: $local_path${NC}"
        exit 1
    fi
    
    local size
    size=$(du -sh "$local_path" 2>/dev/null | cut -f1)
    
    echo -e "${BLUE}Uploading:${NC} $local_path (${size})"
    echo -e "${BLUE}To:${NC} $INSTANCE:$REMOTE"
    echo ""
    
    # Check if large file and warn
    local size_bytes
    size_bytes=$(du -sb "$local_path" 2>/dev/null | cut -f1 || echo "0")
    if [[ "$size_bytes" -gt 1073741824 ]]; then  # 1GB
        echo -e "${YELLOW}Warning: File >1GB. Consider using GCS sync for better reliability.${NC}"
        echo "  $(basename "$0") sync-up $local_path gs://your-bucket/path/"
        echo ""
        read -p "Continue with SCP anyway? (yes/no): " confirm
        [[ "$confirm" != "yes" ]] && exit 0
    fi
    
    local cmd="$(build_scp_cmd)"
    
    if $cmd "$local_path" "$INSTANCE:$REMOTE"; then
        echo ""
        echo -e "${GREEN}✓ Upload complete${NC}"
    else
        echo ""
        echo -e "${RED}✗ Upload failed${NC}"
        exit 1
    fi
}

cmd_download() {
    local remote_spec="$1"
    local local_path="$2"
    
    [[ -z "$remote_spec" ]] && { echo -e "${RED}Error: Remote path required${NC}"; exit 1; }
    [[ -z "$local_path" ]] && { echo -e "${RED}Error: Local path required${NC}"; exit 1; }
    
    parse_remote_path "$remote_spec"
    
    echo -e "${BLUE}Downloading from:${NC} $INSTANCE:$REMOTE"
    echo -e "${BLUE}To:${NC} $local_path"
    echo ""
    
    local cmd="$(build_scp_cmd)"
    
    if $cmd "$INSTANCE:$REMOTE" "$local_path"; then
        echo ""
        echo -e "${GREEN}✓ Download complete${NC}"
        
        local size
        size=$(du -sh "$local_path" 2>/dev/null | cut -f1)
        echo "  Size: $size"
    else
        echo ""
        echo -e "${RED}✗ Download failed${NC}"
        exit 1
    fi
}

cmd_sync_up() {
    local local_dir="$1"
    local gcs_bucket="$2"
    
    [[ -z "$local_dir" ]] && { echo -e "${RED}Error: Local directory required${NC}"; exit 1; }
    [[ -z "$gcs_bucket" ]] && { echo -e "${RED}Error: GCS bucket required${NC}"; exit 1; }
    
    if [[ ! -d "$local_dir" ]]; then
        echo -e "${RED}Error: Local path is not a directory: $local_dir${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Syncing to GCS:${NC}"
    echo "  From: $local_dir"
    echo "  To: $gcs_bucket"
    echo ""
    
    if gcloud storage rsync -r "$local_dir" "$gcs_bucket"; then
        echo -e "${GREEN}✓ Sync complete${NC}"
        echo ""
        echo "To download on VM, run:"
        echo "  gcloud storage cp -r $gcs_bucket /destination/path"
    else
        echo -e "${RED}✗ Sync failed${NC}"
        exit 1
    fi
}

cmd_sync_down() {
    local gcs_bucket="$1"
    local local_dir="$2"
    
    [[ -z "$gcs_bucket" ]] && { echo -e "${RED}Error: GCS bucket required${NC}"; exit 1; }
    [[ -z "$local_dir" ]] && { echo -e "${RED}Error: Local directory required${NC}"; exit 1; }
    
    echo -e "${BLUE}Syncing from GCS:${NC}"
    echo "  From: $gcs_bucket"
    echo "  To: $local_dir"
    echo ""
    
    mkdir -p "$local_dir"
    
    if gcloud storage rsync -r "$gcs_bucket" "$local_dir"; then
        echo -e "${GREEN}✓ Sync complete${NC}"
    else
        echo -e "${RED}✗ Sync failed${NC}"
        exit 1
    fi
}

# Main
cmd="${1:-}"
shift || true

parse_opts "$@"

# Remove parsed opts from args
args=()
for arg in "$@"; do
    [[ "$arg" =~ ^--(zone|project|recurse)$ ]] || [[ "$arg" =~ ^--(zone|project)= ]] || args+=("$arg")
done
set -- "${args[@]}"

case "$cmd" in
    upload)
        cmd_upload "${1:-}" "${2:-}"
        ;;
    download)
        cmd_download "${1:-}" "${2:-}"
        ;;
    sync-up)
        cmd_sync_up "${1:-}" "${2:-}"
        ;;
    sync-down)
        cmd_sync_down "${1:-}" "${2:-}"
        ;;
    *)
        show_help
        exit 0
        ;;
esac
