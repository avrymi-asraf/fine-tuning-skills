#!/bin/bash
#
# Handle preemption for spot VM training jobs
# Automatically restarts jobs that get preempted
#
# Usage:
#   ./handle-preemption.sh --config job_config.yaml [--max-retries 5]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE=""
MAX_RETRIES="${MAX_RETRIES:-5}"
REGION="${REGION:-us-central1}"
JOB_PREFIX=""
RETRY_DELAY="${RETRY_DELAY:-60}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Handle preemption for Vertex AI spot training jobs by automatically restarting them.

Required:
  --config FILE        Path to job config YAML file

Optional:
  --max-retries N      Maximum retry attempts (default: 5)
  --region REGION      GCP region (default: us-central1)
  --prefix PREFIX      Job name prefix
  --retry-delay SEC    Seconds to wait between retries (default: 60)
  --help               Show this help

Examples:
  $0 --config training_config.yaml
  $0 --config training_config.yaml --max-retries 10 --region europe-west4
  MAX_RETRIES=3 $0 --config training_config.yaml

EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --max-retries)
            MAX_RETRIES="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --prefix)
            JOB_PREFIX="$2"
            shift 2
            ;;
        --retry-delay)
            RETRY_DELAY="$2"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Validate
if [ -z "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: --config required${NC}"
    usage
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Config file not found: $CONFIG_FILE${NC}"
    exit 1
fi

# Check dependencies
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI not found${NC}"
    exit 1
fi

# Generate job name
GENERATED_PREFIX="${JOB_PREFIX:-$(basename "$CONFIG_FILE" .yaml)}"
RETRY_COUNT=0
LAST_JOB_ID=""

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Spot VM Preemption Handler${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Config:       $CONFIG_FILE"
echo "Region:       $REGION"
echo "Max Retries:  $MAX_RETRIES"
echo "Retry Delay:  ${RETRY_DELAY}s"
echo ""

# Function to submit job
submit_job() {
    local attempt=$1
    local job_name="${GENERATED_PREFIX}-attempt-${attempt}"
    
    echo -e "${BLUE}[Attempt $attempt/$MAX_RETRIES] Submitting job: $job_name${NC}"
    
    # Submit using the submit script if available, else gcloud directly
    if [ -f "$SCRIPT_DIR/submit-training-job.py" ]; then
        JOB_OUTPUT=$(python3 "$SCRIPT_DIR/submit-training-job.py" \
            --config "$CONFIG_FILE" \
            --display-name "$job_name" \
            --region "$REGION" \
            --save-job-id /tmp/.preemption_job_id 2>&1)
        
        if [ $? -eq 0 ]; then
            LAST_JOB_ID=$(cat /tmp/.preemption_job_id 2>/dev/null)
            echo -e "${GREEN}✓ Job submitted: $LAST_JOB_ID${NC}"
            return 0
        else
            echo -e "${RED}✗ Failed to submit job${NC}"
            echo "$JOB_OUTPUT"
            return 1
        fi
    else
        # Direct gcloud submission
        # Ensure spot is enabled in config
        JOB_ID=$(gcloud ai custom-jobs create \
            --region="$REGION" \
            --display-name="$job_name" \
            --config="$CONFIG_FILE" \
            --format='value(name)' 2>&1)
        
        if [ $? -eq 0 ]; then
            LAST_JOB_ID="$JOB_ID"
            echo -e "${GREEN}✓ Job submitted: $LAST_JOB_ID${NC}"
            return 0
        else
            echo -e "${RED}✗ Failed to submit job${NC}"
            echo "$JOB_ID"
            return 1
        fi
    fi
}

# Function to check job status
check_job_status() {
    local job_id=$1
    gcloud ai custom-jobs describe "$job_id" \
        --region="$REGION" \
        --format='value(state)' 2>/dev/null
}

# Function to wait for job completion
wait_for_job() {
    local job_id=$1
    local start_time=$(date +%s)
    
    echo "Monitoring job: $job_id"
    echo "Press Ctrl+C to stop (job continues running)"
    echo ""
    
    while true; do
        STATUS=$(check_job_status "$job_id")
        CURRENT_TIME=$(date +%s)
        ELAPSED=$((CURRENT_TIME - start_time))
        ELAPSED_STR=$(printf '%02d:%02d:%02d' $((ELAPSED/3600)) $((ELAPSED%3600/60)) $((ELAPSED%60)))
        
        printf '\r%s' "$(tput el)[${ELAPSED_STR}] Status: $STATUS"
        
        case "$STATUS" in
            "JOB_STATE_SUCCEEDED")
                echo ""
                echo ""
                echo -e "${GREEN}✓ Job completed successfully!${NC}"
                return 0
                ;;
            "JOB_STATE_FAILED")
                echo ""
                echo ""
                echo -e "${RED}✗ Job failed${NC}"
                return 1
                ;;
            "JOB_STATE_CANCELLED")
                echo ""
                echo ""
                echo -e "${YELLOW}⚠ Job was cancelled${NC}"
                return 2
                ;;
            "JOB_STATE_PREEMPTING"|"JOB_STATE_PREEMPTED")
                echo ""
                echo ""
                echo -e "${YELLOW}⚠ Job was preempted${NC}"
                return 3
                ;;
            "JOB_STATE_PENDING")
                # Still waiting for resources
                ;;
            "JOB_STATE_RUNNING")
                # Normal running state
                ;;
            "")
                echo ""
                echo ""
                echo -e "${RED}✗ Lost connection to job${NC}"
                return 4
                ;;
        esac
        
        sleep 30
    done
}

# Main retry loop
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Attempt $RETRY_COUNT of $MAX_RETRIES${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Submit job
    if ! submit_job $RETRY_COUNT; then
        echo -e "${RED}Failed to submit job, aborting${NC}"
        exit 1
    fi
    
    # Wait for completion
    wait_for_job "$LAST_JOB_ID"
    EXIT_CODE=$?
    
    case $EXIT_CODE in
        0)
            # Success
            echo ""
            echo -e "${GREEN}========================================${NC}"
            echo -e "${GREEN}  All done!${NC}"
            echo -e "${GREEN}========================================${NC}"
            echo ""
            echo "Total attempts: $RETRY_COUNT"
            echo "Final job ID:   $LAST_JOB_ID"
            
            # Get output location
            OUTPUT_DIR=$(gcloud ai custom-jobs describe "$LAST_JOB_ID" \
                --region="$REGION" \
                --format='value(jobSpec.baseOutputDirectory.outputUriPrefix)' 2>/dev/null)
            if [ -n "$OUTPUT_DIR" ]; then
                echo "Output:         $OUTPUT_DIR"
            fi
            
            exit 0
            ;;
        1|2|4)
            # Failed, cancelled, or lost connection - don't retry
            echo ""
            echo -e "${RED}Job did not complete due to error. Not retrying.${NC}"
            exit 1
            ;;
        3)
            # Preempted - retry
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                echo ""
                echo -e "${YELLOW}Job was preempted. Retrying in ${RETRY_DELAY}s...${NC}"
                echo "(Press Ctrl+C to stop retries)"
                sleep "$RETRY_DELAY"
            fi
            ;;
    esac
done

# Max retries reached
echo ""
echo -e "${RED}========================================${NC}"
echo -e "${RED}  Max retries ($MAX_RETRIES) reached${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo "The job kept getting preempted. Options:"
echo "  1. Use on-demand instances instead of spot"
echo "  2. Try a different region"
echo "  3. Use a smaller machine type (better spot availability)"
echo "  4. Use Dynamic Workload Scheduler for GPU-heavy jobs"
echo ""
exit 1
