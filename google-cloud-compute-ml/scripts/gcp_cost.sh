#!/bin/bash
#
# gcp_cost.sh - Cost management and optimization for ML workloads
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
  estimate [options]            Estimate costs for a configuration
  schedule-stop <name> [opts]   Schedule automatic instance stop
  cancel-schedule <name>        Cancel scheduled stop
  report [options]              Show cost report/billing summary

Options for estimate:
  --gpu-type=<type>             GPU type (default: nvidia-tesla-t4)
  --machine-type=<type>         Machine type (default: n1-standard-4)
  --hours-per-day=<n>           Hours per day (default: 8)
  --days-per-month=<n>          Days per month (default: 22)

Options for schedule-stop:
  --after-hours=<n>             Stop after N hours (default: 8)
  --at-time=<HH:MM>             Stop at specific time
  --zone=<zone>                 Zone (default: $DEFAULT_ZONE)

Examples:
  # Estimate monthly cost
  $(basename "$0") estimate --gpu-type=nvidia-tesla-t4 --hours-per-day=8

  # Schedule auto-stop after 8 hours
  $(basename "$0") schedule-stop gemma-trainer --after-hours=8

  # Schedule stop at midnight
  $(basename "$0") schedule-stop gemma-trainer --at-time=00:00

  # View billing report
  $(basename "$0") report

Pricing (us-central1, approximate):
  nvidia-tesla-t4:  ~\$0.35/hour
  nvidia-l4:        ~\$0.75/hour  
  nvidia-a100-40gb: ~\$2.50/hour
  nvidia-a100-80gb: ~\$3.67/hour

  n1-standard-4:    ~\$0.19/hour
  n1-standard-8:    ~\$0.38/hour
  n1-standard-16:   ~\$0.76/hour

Notes:
  - You are charged for GPUs only while instance is RUNNING
  - Stopped instances still incur disk charges (~\$0.04/GB/month)
  - Spot instances are 60-90% cheaper but can be preempted

EOF
}

# Pricing (approximate, us-central1)
declare -A GPU_PRICING=(
    ["nvidia-tesla-t4"]=0.35
    ["nvidia-l4"]=0.75
    ["nvidia-a100-40gb"]=2.50
    ["nvidia-a100-80gb"]=3.67
)

declare -A MACHINE_PRICING=(
    ["n1-standard-4"]=0.19
    ["n1-standard-8"]=0.38
    ["n1-standard-16"]=0.76
    ["n1-standard-32"]=1.52
    ["n1-highmem-4"]=0.24
    ["n1-highmem-8"]=0.48
    ["n1-highmem-16"]=0.96
)

parse_opts() {
    GPU_TYPE="nvidia-tesla-t4"
    MACHINE_TYPE="n1-standard-4"
    HOURS_PER_DAY=8
    DAYS_PER_MONTH=22
    AFTER_HOURS=8
    AT_TIME=""
    ZONE="$DEFAULT_ZONE"
    PROJECT=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --gpu-type=*) GPU_TYPE="${1#*=}" ;;
            --machine-type=*) MACHINE_TYPE="${1#*=}" ;;
            --hours-per-day=*) HOURS_PER_DAY="${1#*=}" ;;
            --days-per-month=*) DAYS_PER_MONTH="${1#*=}" ;;
            --after-hours=*) AFTER_HOURS="${1#*=}" ;;
            --at-time=*) AT_TIME="${1#*=}" ;;
            --zone=*) ZONE="${1#*=}" ;;
            --project=*) PROJECT="${1#*=}" ;;
            --) shift; break ;;
            --*) echo "Unknown option: $1"; exit 1 ;;
            *) break ;;
        esac
        shift
    done
}

cmd_estimate() {
    local gpu_hourly=${GPU_PRICING[$GPU_TYPE]:-0.35}
    local machine_hourly=${MACHINE_PRICING[$MACHINE_TYPE]:-0.19}
    
    local total_hourly=$(echo "$gpu_hourly + $machine_hourly" | bc)
    local daily=$(echo "$total_hourly * $HOURS_PER_DAY" | bc)
    local monthly=$(echo "$daily * $DAYS_PER_MONTH" | bc)
    
    # Add disk cost (100GB SSD ~$4/month)
    local disk_monthly=4
    local total_monthly=$(echo "$monthly + $disk_monthly" | bc)
    
    echo -e "${BLUE}Cost Estimate${NC}"
    echo ""
    echo "Configuration:"
    echo "  GPU: $GPU_TYPE"
    echo "  Machine: $MACHINE_TYPE"
    echo "  Usage: $HOURS_PER_DAY hours/day, $DAYS_PER_MONTH days/month"
    echo ""
    echo "Pricing (us-central1):"
    printf "  GPU (%s):    $%.2f/hour\n" "$GPU_TYPE" "$gpu_hourly"
    printf "  Machine (%s): $%.2f/hour\n" "$MACHINE_TYPE" "$machine_hourly"
    printf "  Disk (100GB): $%.2f/month\n" "$disk_monthly"
    echo ""
    echo "Estimated Costs:"
    printf "  Per hour:    $%.2f\n" "$total_hourly"
    printf "  Per day:     $%.2f\n" "$daily"
    printf "  Per month:   $%.2f\n" "$total_monthly"
    echo ""
    echo -e "${YELLOW}Spot instance price: ~$$(echo "$total_monthly * 0.25" | bc)/month (75% savings)${NC}"
    echo ""
    echo "Notes:"
    echo "  - Prices are approximate and may vary by region"
    echo "  - Stopped instances don't incur GPU/CPU charges"
    echo "  - Disk is charged even when stopped"
}

cmd_schedule_stop() {
    local name="$1"
    [[ -z "$name" ]] && { echo -e "${RED}Error: Instance name required${NC}"; exit 1; }
    
    if [[ -n "$AT_TIME" ]]; then
        echo -e "${BLUE}Scheduling $name to stop at $AT_TIME${NC}"
        
        # Convert time to seconds from now
        local current_epoch=$(date +%s)
        local target_epoch=$(date -d "$AT_TIME" +%s 2>/dev/null) || {
            echo -e "${RED}Invalid time format: $AT_TIME${NC}"
            echo "Use 24-hour format: HH:MM"
            exit 1
        }
        
        # If time already passed today, assume tomorrow
        if [[ $target_epoch -lt $current_epoch ]]; then
            target_epoch=$(date -d "tomorrow $AT_TIME" +%s)
        fi
        
        local delay_seconds=$((target_epoch - current_epoch))
        local delay_hours=$(echo "scale=2; $delay_seconds / 3600" | bc)
        
        echo "Will stop in ~$delay_hours hours"
        
        # Schedule with at or background process
        (
            sleep $delay_seconds
            gcloud compute instances stop "$name" --zone="$ZONE" --quiet 2>/dev/null || true
        ) &
        
        local job_id=$!
        echo $job_id > "/tmp/gcp-stop-$name.pid"
        
        echo -e "${GREEN}✓ Scheduled stop (job ID: $job_id)${NC}"
        echo "Cancel with: kill $job_id  or  $(basename "$0") cancel-schedule $name"
        
    else
        echo -e "${BLUE}Scheduling $name to stop after $AFTER_HOURS hours${NC}"
        
        local delay_seconds=$((AFTER_HOURS * 3600))
        
        (
            sleep $delay_seconds
            echo "Stopping instance $name..."
            gcloud compute instances stop "$name" --zone="$ZONE" --quiet 2>/dev/null || true
        ) &
        
        local job_id=$!
        echo $job_id > "/tmp/gcp-stop-$name.pid"
        
        echo -e "${GREEN}✓ Scheduled stop in $AFTER_HOURS hours (job ID: $job_id)${NC}"
        echo "Cancel with: $(basename "$0") cancel-schedule $name"
    fi
}

cmd_cancel_schedule() {
    local name="$1"
    [[ -z "$name" ]] && { echo -e "${RED}Error: Instance name required${NC}"; exit 1; }
    
    local pid_file="/tmp/gcp-stop-$name.pid"
    
    if [[ -f "$pid_file" ]]; then
        local job_id=$(cat "$pid_file")
        if kill "$job_id" 2>/dev/null; then
            echo -e "${GREEN}✓ Cancelled scheduled stop for $name${NC}"
            rm -f "$pid_file"
        else
            echo -e "${YELLOW}Job $job_id not found (may have already completed)${NC}"
            rm -f "$pid_file"
        fi
    else
        echo -e "${YELLOW}No scheduled stop found for $name${NC}"
    fi
}

cmd_report() {
    echo -e "${BLUE}GCP Cost Report${NC}"
    echo ""
    
    # Get current project
    local project=$(gcloud config get-value project 2>/dev/null)
    echo "Project: $project"
    echo ""
    
    # List running instances (costing money)
    echo "Running Instances (incurring charges):"
    echo "======================================"
    
    local running=$(gcloud compute instances list --format="table(
        name,
        zone.basename(),
        machineType.basename(),
        guestAccelerators[0].acceleratorType.basename():label=GPU,
        status
    )" --filter="status:RUNNING" 2>/dev/null) || true
    
    if [[ -n "$running" ]]; then
        echo "$running"
    else
        echo "  None (good job saving money!)"
    fi
    
    echo ""
    echo "Stopped Instances (disk charges only):"
    echo "======================================="
    
    local stopped=$(gcloud compute instances list --format="table(
        name,
        zone.basename(),
        machineType.basename(),
        status
    )" --filter="status:TERMINATED" 2>/dev/null) || true
    
    if [[ -n "$stopped" ]]; then
        echo "$stopped"
    else
        echo "  None"
    fi
    
    echo ""
    echo -e "${YELLOW}Tip: Use './gcp_compute.sh stop <name>' to stop instances and save money${NC}"
    
    # Note about billing
    echo ""
    echo "For detailed billing, visit:"
    echo "  https://console.cloud.google.com/billing"
}

# Main
cmd="${1:-}"
shift || true

parse_opts "$@"

# Remove parsed opts from args
args=()
for arg in "$@"; do
    [[ "$arg" =~ ^-- ]] || args+=("$arg")
done
set -- "${args[@]}"

case "$cmd" in
    estimate)
        cmd_estimate
        ;;
    schedule-stop)
        cmd_schedule_stop "${1:-}"
        ;;
    cancel-schedule)
        cmd_cancel_schedule "${1:-}"
        ;;
    report)
        cmd_report
        ;;
    *)
        show_help
        exit 0
        ;;
esac
