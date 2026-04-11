#!/bin/bash
#
# Cancel/Stop a running Vertex AI training job
#
# Usage:
#   ./cancel-job.sh JOB_ID [REGION]
#   ./cancel-job.sh $(cat .last_job_id)
#

set -e

JOB_ID="${1:-}"
REGION="${2:-us-central1}"
FORCE="${FORCE:-false}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    echo "Usage: $0 JOB_ID [REGION]"
    echo ""
    echo "Options:"
    echo "  FORCE=true $0 JOB_ID    - Skip confirmation"
    echo ""
    echo "Examples:"
    echo "  $0 1234567890123456789"
    echo "  $0 1234567890123456789 europe-west4"
    echo "  FORCE=true $0 1234567890123456789"
    exit 1
}

if [ -z "$JOB_ID" ]; then
    echo -e "${RED}Error: JOB_ID required${NC}"
    usage
fi

# Check gcloud
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI not found${NC}"
    exit 1
fi

# Get job info
echo -e "${BLUE}Fetching job details...${NC}"
JOB_INFO=$(gcloud ai custom-jobs describe "$JOB_ID" --region="$REGION" 2>/dev/null) || {
    echo -e "${RED}Error: Job not found or no access${NC}"
    exit 1
}

NAME=$(echo "$JOB_INFO" | grep "displayName:" | head -1 | cut -d: -f2 | xargs)
STATE=$(echo "$JOB_INFO" | grep "state:" | head -1 | cut -d: -f2 | xargs)

echo ""
echo "Job Details:"
echo "  ID:     $JOB_ID"
echo "  Name:   $NAME"
echo "  State:  $STATE"
echo "  Region: $REGION"
echo ""

# Check if job is already terminal
case "$STATE" in
    "JOB_STATE_SUCCEEDED"|"JOB_STATE_FAILED"|"JOB_STATE_CANCELLED"|"JOB_STATE_PREEMPTED")
        echo -e "${YELLOW}Job is already in terminal state: $STATE${NC}"
        echo "No action needed."
        exit 0
        ;;
esac

# Confirmation
if [ "$FORCE" != "true" ]; then
    echo -e "${YELLOW}Are you sure you want to cancel this job?${NC}"
    echo -n "Type 'yes' to confirm: "
    read CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        echo "Cancelled."
        exit 0
    fi
fi

# Cancel the job
echo ""
echo -e "${BLUE}Cancelling job...${NC}"

if gcloud ai custom-jobs cancel "$JOB_ID" --region="$REGION" 2>&1; then
    echo -e "${GREEN}✓ Cancel request sent successfully${NC}"
    echo ""
    echo "The job will stop shortly. Any checkpoints saved will be preserved."
    echo ""
    echo "Monitor with:"
    echo "  gcloud ai custom-jobs describe $JOB_ID --region=$REGION"
else
    echo -e "${RED}✗ Failed to cancel job${NC}"
    exit 1
fi

# Show final status
echo ""
echo "Waiting for job to stop..."
sleep 3

FINAL_STATE=$(gcloud ai custom-jobs describe "$JOB_ID" \
    --region="$REGION" \
    --format='value(state)' 2>/dev/null)

echo "Current state: $FINAL_STATE"

# Get output location if available
OUTPUT_DIR=$(echo "$JOB_INFO" | grep "outputUriPrefix:" | head -1 | cut -d: -f2- | xargs)
if [ -n "$OUTPUT_DIR" ]; then
    echo ""
    echo "Output directory (checkpoints may be here):"
    echo "  $OUTPUT_DIR"
fi
