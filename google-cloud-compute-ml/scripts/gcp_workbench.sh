#!/bin/bash
#
# gcp_workbench.sh - Manage Vertex AI Workbench instances
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DEFAULT_REGION="us-central1"
DEFAULT_MACHINE_TYPE="n1-standard-4"

gshow_help() {
    cat << EOF
Usage: $(basename "$0") <command> [options]

Commands:
  create <name> [options]       Create a new Workbench instance
  delete <name> [options]       Delete a Workbench instance
  list [options]                List all Workbench instances
  open <name> [options]         Open Jupyter in browser
  start <name> [options]        Start a stopped instance
  stop <name> [options]         Stop a running instance

Options:
  --region=<region>             Region (default: $DEFAULT_REGION)
  --project=<project>           GCP project ID
  --machine-type=<type>         Machine type (default: $DEFAULT_MACHINE_TYPE)
  --gpu-type=<type>             GPU type: T4, L4, A100 (default: none)
  --gpu-count=<n>               Number of GPUs (default: 1)

Examples:
  # Create CPU-only instance
  $(basename "$0") create my-notebook

  # Create with T4 GPU
  $(basename "$0") create my-notebook --gpu-type=T4 --machine-type=n1-standard-4

  # List instances
  $(basename "$0") list

  # Open Jupyter
  $(basename "$0") open my-notebook

  # Stop to save money
  $(basename "$0") stop my-notebook

Notes:
  - Workbench instances are managed Jupyter environments
  - Less control than raw Compute Engine, easier setup
  - For Unsloth, install packages via terminal in Jupyter

EOF
}

parse_opts() {
    REGION="$DEFAULT_REGION"
    PROJECT=""
    MACHINE_TYPE="$DEFAULT_MACHINE_TYPE"
    GPU_TYPE=""
    GPU_COUNT=1
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --region=*) REGION="${1#*=}" ;;
            --project=*) PROJECT="${1#*=}" ;;
            --machine-type=*) MACHINE_TYPE="${1#*=}" ;;
            --gpu-type=*) GPU_TYPE="${1#*=}" ;;
            --gpu-count=*) GPU_COUNT="${1#*=}" ;;
            --) shift; break ;;
            --*) echo "Unknown option: $1"; exit 1 ;;
            *) break ;;
        esac
        shift
    done
}

build_gcloud_cmd() {
    local cmd="gcloud notebooks"
    [[ -n "$PROJECT" ]] && cmd="$cmd --project=$PROJECT"
    cmd="$cmd --location=$REGION"
    echo "$cmd"
}

cmd_create() {
    local name="$1"
    [[ -z "$name" ]] && { echo -e "${RED}Error: Instance name required${NC}"; exit 1; }
    
    echo -e "${BLUE}Creating Workbench instance: $name${NC}"
    echo "  Region: $REGION"
    echo "  Machine: $MACHINE_TYPE"
    [[ -n "$GPU_TYPE" ]] && echo "  GPU: $GPU_TYPE x$GPU_COUNT"
    echo ""
    
    local cmd="$(build_gcloud_cmd) instances create $name"
    cmd="$cmd --vm-image-project=deeplearning-platform-release"
    cmd="$cmd --vm-image-family=common-cu121"
    cmd="$cmd --machine-type=$MACHINE_TYPE"
    
    if [[ -n "$GPU_TYPE" ]]; then
        cmd="$cmd --accelerator-type=$GPU_TYPE"
        cmd="$cmd --accelerator-core-count=$GPU_COUNT"
        cmd="$cmd --install-nvidia-driver"
    fi
    
    if $cmd; then
        echo ""
        echo -e "${GREEN}✓ Workbench instance created${NC}"
        echo ""
        echo "To open Jupyter:"
        echo "  $(basename "$0") open $name"
        echo ""
        echo "Note: Instance may take 2-3 minutes to be ready"
    else
        echo -e "${RED}✗ Failed to create instance${NC}"
        exit 1
    fi
}

cmd_delete() {
    local name="$1"
    [[ -z "$name" ]] && { echo -e "${RED}Error: Instance name required${NC}"; exit 1; }
    
    echo -e "${RED}WARNING: This will permanently delete Workbench instance '$name'${NC}"
    read -p "Are you sure? (yes/no): " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        echo "Deleting..."
        $(build_gcloud_cmd) instances delete "$name"
        echo -e "${GREEN}✓ Instance deleted${NC}"
    else
        echo "Cancelled"
    fi
}

cmd_list() {
    echo -e "${BLUE}Vertex AI Workbench instances:${NC}"
    echo ""
    $(build_gcloud_cmd) instances list --format="table(
        name,
        state,
        machineType.basename(),
        acceleratorConfigs[0].type:label=GPU,
        createTime.date('%Y-%m-%d')
    )"
}

cmd_open() {
    local name="$1"
    [[ -z "$name" ]] && { echo -e "${RED}Error: Instance name required${NC}"; exit 1; }
    
    echo -e "${BLUE}Getting Jupyter URL for $name...${NC}"
    
    # Get the proxy URI
    local proxy_uri
    proxy_uri=$($(build_gcloud_cmd) instances describe "$name" --format="value(proxyUri)" 2>/dev/null) || true
    
    if [[ -z "$proxy_uri" ]]; then
        echo -e "${YELLOW}Instance not ready or not found${NC}"
        echo "Check status with: $(basename "$0") list"
        exit 1
    fi
    
    local url="https://$proxy_uri"
    
    echo "Jupyter URL: $url"
    echo ""
    echo -e "${GREEN}Opening browser...${NC}"
    
    # Try to open browser
    if command -v xdg-open &>/dev/null; then
        xdg-open "$url"
    elif command -v open &>/dev/null; then
        open "$url"
    else
        echo "Please open this URL in your browser:"
        echo "  $url"
    fi
}

cmd_start() {
    local name="$1"
    [[ -z "$name" ]] && { echo -e "${RED}Error: Instance name required${NC}"; exit 1; }
    
    echo -e "${GREEN}Starting Workbench instance: $name${NC}"
    $(build_gcloud_cmd) instances start "$name"
    echo -e "${GREEN}✓ Instance started${NC}"
}

cmd_stop() {
    local name="$1"
    [[ -z "$name" ]] && { echo -e "${RED}Error: Instance name required${NC}"; exit 1; }
    
    echo -e "${YELLOW}Stopping Workbench instance: $name${NC}"
    $(build_gcloud_cmd) instances stop "$name"
    echo -e "${GREEN}✓ Instance stopped${NC}"
}

# Main
cmd="${1:-}"
shift || true

parse_opts "$@"

# Remove parsed opts from args
args=()
for arg in "$@"; do
    [[ "$arg" =~ ^--(region|project|machine-type|gpu-type|gpu-count)= ]] || args+=("$arg")
done
set -- "${args[@]}"

case "$cmd" in
    create)
        cmd_create "${1:-}"
        ;;
    delete)
        cmd_delete "${1:-}"
        ;;
    list)
        cmd_list
        ;;
    open)
        cmd_open "${1:-}"
        ;;
    start)
        cmd_start "${1:-}"
        ;;
    stop)
        cmd_stop "${1:-}"
        ;;
    *)
        gshow_help
        exit 0
        ;;
esac
