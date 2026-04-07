#!/bin/bash
#
# gcp_compute.sh - Manage GPU-enabled Compute Engine instances for ML workloads
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
DEFAULT_MACHINE_TYPE="n1-standard-4"
DEFAULT_GPU_TYPE="nvidia-tesla-t4"
DEFAULT_REGION="us-central1"
DEFAULT_ZONE="us-central1-a"
DEFAULT_IMAGE_FAMILY="common-cu121"
DEFAULT_IMAGE_PROJECT="deeplearning-platform-release"
DEFAULT_DISK_SIZE="100GB"

show_help() {
    cat << EOF
Usage: $(basename "$0") <command> [options]

Commands:
  create <name> [options]     Create a new GPU-enabled VM
  start <name> [options]      Start a stopped VM
  stop <name> [options]       Stop a running VM (saves money)
  delete <name> [options]     Permanently delete a VM
  list [options]              List all instances with GPU info
  status <name> [options]     Show detailed status of a VM
  resize <name> <type>        Change machine type (must be stopped)

Options for create:
  --gpu-type=<type>           GPU type: nvidia-tesla-t4, nvidia-l4, nvidia-a100-40gb, nvidia-a100-80gb (default: $DEFAULT_GPU_TYPE)
  --machine-type=<type>       Machine type (default: $DEFAULT_MACHINE_TYPE)
  --region=<region>           Region (default: $DEFAULT_REGION)
  --zone=<zone>              Zone (default: $DEFAULT_ZONE)
  --spot                     Use spot instance (60-90% cheaper, can be preempted)
  --image-family=<family>     Image family (default: $DEFAULT_IMAGE_FAMILY)
  --disk-size=<size>         Boot disk size (default: $DEFAULT_DISK_SIZE)

Global options:
  --project=<project>         GCP project ID (uses gcloud default if not set)
  --zone=<zone>              Zone for the instance

Examples:
  $(basename "$0") create gemma-trainer
  $(basename "$0") create gemma-trainer --gpu-type=nvidia-tesla-t4 --machine-type=n1-standard-4 --region=us-central1
  $(basename "$0") create gemma-trainer --spot
  $(basename "$0") stop gemma-trainer
  $(basename "$0") list
  $(basename "$0") status gemma-trainer

EOF
}

# Parse global options
PROJECT=""
ZONE=""
parse_global_opts() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --project=*) PROJECT="${1#*=}" ;;
            --zone=*) ZONE="${1#*=}" ;;
            *) break ;;
        esac
        shift
    done
}

# Build gcloud base command with project/zone
build_gcloud_cmd() {
    local cmd="gcloud compute"
    if [[ -n "$PROJECT" ]]; then
        cmd="$cmd --project=$PROJECT"
    fi
    if [[ -n "$ZONE" ]]; then
        cmd="$cmd --zone=$ZONE"
    fi
    echo "$cmd"
}

create_instance() {
    local name="$1"
    shift
    
    local gpu_type="$DEFAULT_GPU_TYPE"
    local machine_type="$DEFAULT_MACHINE_TYPE"
    local region="$DEFAULT_REGION"
    local zone="$DEFAULT_ZONE"
    local image_family="$DEFAULT_IMAGE_FAMILY"
    local disk_size="$DEFAULT_DISK_SIZE"
    local spot=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --gpu-type=*) gpu_type="${1#*=}" ;;
            --machine-type=*) machine_type="${1#*=}" ;;
            --region=*) region="${1#*=}" ;;
            --zone=*) zone="${1#*=}" ;;
            --image-family=*) image_family="${1#*=}" ;;
            --disk-size=*) disk_size="${1#*=}" ;;
            --spot) spot="--provisioning-model=SPOT" ;;
            --project=*|--zone=*) ;; # Handled by parse_global_opts
            *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
        esac
        shift
    done
    
    echo -e "${GREEN}Creating VM '$name' with GPU...${NC}"
    echo "  GPU: $gpu_type"
    echo "  Machine: $machine_type"
    echo "  Zone: $zone"
    [[ -n "$spot" ]] && echo "  Spot instance: Yes"
    
    local cmd="$(build_gcloud_cmd) instances create $name"
    cmd="$cmd --zone=$zone"
    cmd="$cmd --machine-type=$machine_type"
    cmd="$cmd --accelerator=type=$gpu_type,count=1"
    cmd="$cmd --image-family=$image_family"
    cmd="$cmd --image-project=$DEFAULT_IMAGE_PROJECT"
    cmd="$cmd --boot-disk-size=$disk_size"
    cmd="$cmd --boot-disk-type=pd-ssd"
    cmd="$cmd --maintenance-policy=TERMINATE"
    [[ -n "$spot" ]] && cmd="$cmd $spot"
    
    if $cmd; then
        echo -e "${GREEN}✓ VM '$name' created successfully${NC}"
        echo ""
        echo "To connect: ./gcp_ssh.sh connect $name"
        echo "To check GPU: ./gcp_ssh.sh command $name \"nvidia-smi\""
    else
        echo -e "${RED}✗ Failed to create VM${NC}"
        echo "Common issues:"
        echo "  - GPU quota exceeded in zone $zone"
        echo "  - Billing not enabled on project"
        exit 1
    fi
}

start_instance() {
    local name="$1"
    echo -e "${GREEN}Starting VM '$name'...${NC}"
    $(build_gcloud_cmd) instances start "$name"
}

stop_instance() {
    local name="$1"
    echo -e "${YELLOW}Stopping VM '$name'...${NC}"
    $(build_gcloud_cmd) instances stop "$name"
    echo -e "${GREEN}✓ VM stopped. GPU charges stopped.${NC}"
}

delete_instance() {
    local name="$1"
    echo -e "${RED}WARNING: This will permanently delete VM '$name'${NC}"
    read -p "Are you sure? (yes/no): " confirm
    if [[ "$confirm" == "yes" ]]; then
        $(build_gcloud_cmd) instances delete "$name"
        echo -e "${GREEN}✓ VM deleted${NC}"
    else
        echo "Cancelled"
    fi
}

list_instances() {
    echo -e "${GREEN}Compute Engine instances:${NC}"
    $(build_gcloud_cmd) instances list --format="table(
        name,
        zone.basename(),
        machineType.basename(),
        guestAccelerators[0].acceleratorType.basename():label=GPU,
        status,
        networkInterfaces[0].accessConfigs[0].natIP:label=EXTERNAL_IP
    )"
}

show_status() {
    local name="$1"
    echo -e "${GREEN}Status for VM '$name':${NC}"
    $(build_gcloud_cmd) instances describe "$name" --format="table(
        name,
        status,
        machineType.basename(),
        guestAccelerators[0].acceleratorType.basename():label=GPU,
        guestAccelerators[0].acceleratorCount:label=GPU_COUNT,
        cpuPlatform,
        creationTimestamp
    )"
    
    echo ""
    echo "Disks:"
    $(build_gcloud_cmd) instances describe "$name" --format="table(
        disks[0].diskSizeGb:label=SIZE_GB,
        disks[0].diskType.basename():label=TYPE
    )"
}

resize_instance() {
    local name="$1"
    local new_type="$2"
    
    echo -e "${YELLOW}Resizing VM '$name' to $new_type...${NC}"
    echo "VM must be stopped first."
    
    $(build_gcloud_cmd) instances set-machine-type "$name" --machine-type="$new_type"
    echo -e "${GREEN}✓ Machine type updated. Start with: ./gcp_compute.sh start $name${NC}"
}

# Main
cmd="${1:-}"
shift || true

parse_global_opts "$@"

# Remove global opts from args
args=()
for arg in "$@"; do
    [[ "$arg" =~ ^--(project|zone)= ]] || args+=("$arg")
done
set -- "${args[@]}"

case "$cmd" in
    create)
        [[ -z "${1:-}" ]] && { echo "Error: Instance name required"; show_help; exit 1; }
        create_instance "$1" "${@:2}"
        ;;
    start)
        [[ -z "${1:-}" ]] && { echo "Error: Instance name required"; exit 1; }
        start_instance "$1"
        ;;
    stop)
        [[ -z "${1:-}" ]] && { echo "Error: Instance name required"; exit 1; }
        stop_instance "$1"
        ;;
    delete)
        [[ -z "${1:-}" ]] && { echo "Error: Instance name required"; exit 1; }
        delete_instance "$1"
        ;;
    list)
        list_instances
        ;;
    status)
        [[ -z "${1:-}" ]] && { echo "Error: Instance name required"; exit 1; }
        show_status "$1"
        ;;
    resize)
        [[ -z "${1:-}" ]] && { echo "Error: Instance name required"; exit 1; }
        [[ -z "${2:-}" ]] && { echo "Error: New machine type required"; exit 1; }
        resize_instance "$1" "$2"
        ;;
    *)
        show_help
        exit 0
        ;;
esac
