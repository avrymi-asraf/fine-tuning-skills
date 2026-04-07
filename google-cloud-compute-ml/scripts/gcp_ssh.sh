#!/bin/bash
#
# gcp_ssh.sh - SSH connectivity to Compute Engine instances via IAP
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DEFAULT_ZONE="us-central1-a"

show_help() {
    cat << EOF
Usage: $(basename "$0") <command> [options]

Commands:
  connect <instance> [options]     Open interactive SSH session
  command <instance> <cmd>         Run a single command and exit
  tunnel <instance> [options]      Set up port forwarding tunnel

Options:
  --zone=<zone>                    Zone (default: $DEFAULT_ZONE)
  --project=<project>              GCP project ID

Tunnel options:
  --local-port=<port>              Local port (default: 8888)
  --remote-port=<port>             Remote port (default: 8888)

Examples:
  $(basename "$0") connect gemma-trainer
  $(basename "$0") connect gemma-trainer --zone=us-west1-b
  $(basename "$0") command gemma-trainer "nvidia-smi"
  $(basename "$0") tunnel gemma-trainer --local-port=8888 --remote-port=8888
  $(basename "$0") command gemma-trainer "ls -la /home/\$USER/"

Notes:
  - Uses IAP tunneling (secure, no public IP needed)
  - First connection may take 10-20 seconds to establish
  - Use tmux/screen inside the VM for persistent sessions

EOF
}

parse_opts() {
    ZONE="$DEFAULT_ZONE"
    PROJECT=""
    LOCAL_PORT="8888"
    REMOTE_PORT="8888"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --zone=*) ZONE="${1#*=}" ;;
            --project=*) PROJECT="${1#*=}" ;;
            --local-port=*) LOCAL_PORT="${1#*=}" ;;
            --remote-port=*) REMOTE_PORT="${1#*=}" ;;
            --) shift; break ;;
            --*) echo "Unknown option: $1"; exit 1 ;;
            *) break ;;
        esac
        shift
    done
}

build_base_cmd() {
    local cmd="gcloud compute ssh"
    [[ -n "$PROJECT" ]] && cmd="$cmd --project=$PROJECT"
    cmd="$cmd --zone=$ZONE"
    cmd="$cmd --tunnel-through-iap"
    echo "$cmd"
}

cmd_connect() {
    local instance="$1"
    
    echo -e "${GREEN}Connecting to '$instance' via IAP...${NC}"
    echo "Zone: $ZONE"
    echo ""
    
    local cmd="$(build_base_cmd) $instance"
    
    echo "Tip: Use 'tmux' or 'screen' for persistent sessions."
    echo ""
    
    exec $cmd
}

cmd_command() {
    local instance="$1"
    shift
    local remote_cmd="$*"
    
    if [[ -z "$remote_cmd" ]]; then
        echo -e "${RED}Error: Command required${NC}"
        exit 1
    fi
    
    local cmd="$(build_base_cmd) $instance --command='$remote_cmd'"
    
    eval "$cmd"
}

cmd_tunnel() {
    local instance="$1"
    
    echo -e "${GREEN}Setting up SSH tunnel to '$instance'...${NC}"
    echo "Local port: $LOCAL_PORT -> Remote port: $REMOTE_PORT"
    echo ""
    echo "Access via: http://localhost:$LOCAL_PORT"
    echo "Press Ctrl+C to stop"
    echo ""
    
    local cmd="$(build_base_cmd) $instance -- -L $LOCAL_PORT:localhost:$REMOTE_PORT -N"
    
    exec $cmd
}

# Main
cmd="${1:-}"
shift || true

parse_opts "$@"

# Remove parsed opts from args
args=()
for arg in "$@"; do
    [[ "$arg" =~ ^--(zone|project|local-port|remote-port)= ]] || args+=("$arg")
done
set -- "${args[@]}"

case "$cmd" in
    connect)
        [[ -z "${1:-}" ]] && { echo -e "${RED}Error: Instance name required${NC}"; show_help; exit 1; }
        cmd_connect "$1"
        ;;
    command)
        [[ -z "${1:-}" ]] && { echo -e "${RED}Error: Instance name required${NC}"; exit 1; }
        [[ -z "${2:-}" ]] && { echo -e "${RED}Error: Command required${NC}"; exit 1; }
        instance="$1"
        shift
        cmd_command "$instance" "$@"
        ;;
    tunnel)
        [[ -z "${1:-}" ]] && { echo -e "${RED}Error: Instance name required${NC}"; show_help; exit 1; }
        cmd_tunnel "$1"
        ;;
    *)
        show_help
        exit 0
        ;;
esac
