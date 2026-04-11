#!/bin/bash
#
# Monitor a Vertex AI training job - stream logs and check status
#
# Usage:
#   ./monitor-job.sh JOB_ID [REGION]
#   ./monitor-job.sh $(cat .last_job_id)
#

set -e

JOB_ID="${1:-}"
REGION="${2:-us-central1}"
POLL_INTERVAL="${POLL_INTERVAL:-30}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 JOB_ID [REGION]"
    echo ""
    echo "Environment variables:"
    echo "  POLL_INTERVAL - Seconds between status checks (default: 30)"
    echo ""
    echo "Examples:"
    echo "  $0 1234567890123456789 us-central1"
    echo "  $0 \$(cat .last_job_id)"
    exit 1
}

if [ -z "$JOB_ID" ]; then
    echo -e "${RED}Error: JOB_ID required${NC}"
    usage
fi

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI not found${NC}"
    echo "Install: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Function to get job status
get_job_status() {
    gcloud ai custom-jobs describe "$JOB_ID" \
        --region="$REGION" \
        --format='value(state)' 2>/dev/null || echo "UNKNOWN"
}

# Function to get job details
get_job_details() {
    gcloud ai custom-jobs describe "$JOB_ID" \
        --region="$REGION" \
        --format='table(
            displayName,
            state,
            createTime,
            startTime,
            endTime,
            error.message
        )' 2>/dev/null
}

# Function to format time
format_time() {
    if command -v date &> /dev/null && [ -n "$1" ]; then
        # Try to parse and format the timestamp
        date -d "$1" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$1"
    else
        echo "$1"
    fi
}

# Function to calculate duration
calculate_duration() {
    local start="$1"
    local end="${2:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
    
    if command -v date &> /dev/null; then
        local start_sec=$(date -d "$start" +%s 2>/dev/null || echo 0)
        local end_sec=$(date -d "$end" +%s 2>/dev/null || echo 0)
        local duration=$((end_sec - start_sec))
        
        printf '%02d:%02d:%02d' $((duration/3600)) $((duration%3600/60)) $((duration%60))
    else
        echo "N/A"
    fi
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Vertex AI Job Monitor${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Job ID:   $JOB_ID"
echo "Region:   $REGION"
echo "Poll:     Every ${POLL_INTERVAL}s"
echo ""

# Check if job exists
STATUS=$(get_job_status)
if [ "$STATUS" = "UNKNOWN" ]; then
    echo -e "${RED}Error: Job not found or no access${NC}"
    echo "Check: gcloud ai custom-jobs describe $JOB_ID --region=$REGION"
    exit 1
fi

echo -e "${GREEN}✓ Job found${NC}"
echo ""

# Show initial details
echo "Job Details:"
get_job_details
echo ""

# Start log streaming in background if job is running
if [ "$STATUS" = "JOB_STATE_PENDING" ] || [ "$STATUS" = "JOB_STATE_RUNNING" ]; then
    echo -e "${YELLOW}Streaming logs... (Press Ctrl+C to stop monitoring, logs continue in background)${NC}"
    echo ""
    
    # Start streaming logs in background
    gcloud ai custom-jobs stream-logs "$JOB_ID" --region="$REGION" &
    LOG_PID=$!
    
    # Trap to clean up log streaming on exit
    cleanup() {
        echo ""
        echo -e "${YELLOW}Stopping log stream...${NC}"
        kill $LOG_PID 2>/dev/null || true
        wait $LOG_PID 2>/dev/null || true
        exit 0
    }
    trap cleanup SIGINT SIGTERM
fi

# Monitor loop
PREV_STATUS=""
START_TIME=""

while true; do
    STATUS=$(get_job_status)
    
    # Show status changes
    if [ "$STATUS" != "$PREV_STATUS" ]; then
        echo ""
        echo -e "${BLUE}[$(date '+%H:%M:%S')] Status: $STATUS${NC}"
        
        case "$STATUS" in
            "JOB_STATE_PENDING")
                echo -e "${YELLOW}  → Job is queued, waiting for resources...${NC}"
                ;;
            "JOB_STATE_RUNNING")
                echo -e "${GREEN}  → Job is now running!${NC}"
                # Get start time
                START_TIME=$(gcloud ai custom-jobs describe "$JOB_ID" \
                    --region="$REGION" \
                    --format='value(startTime)' 2>/dev/null)
                ;;
            "JOB_STATE_SUCCEEDED")
                echo -e "${GREEN}  → Job completed successfully!${NC}"
                break
                ;;
            "JOB_STATE_FAILED")
                echo -e "${RED}  → Job failed!${NC}"
                # Show error details
                ERROR=$(gcloud ai custom-jobs describe "$JOB_ID" \
                    --region="$REGION" \
                    --format='value(error.message)' 2>/dev/null)
                if [ -n "$ERROR" ]; then
                    echo -e "${RED}  Error: $ERROR${NC}"
                fi
                break
                ;;
            "JOB_STATE_CANCELLED")
                echo -e "${YELLOW}  → Job was cancelled${NC}"
                break
                ;;
            "JOB_STATE_PREEMPTING")
                echo -e "${YELLOW}  → Job is being preempted (saving checkpoint...)${NC}"
                ;;
            "JOB_STATE_PREEMPTED")
                echo -e "${YELLOW}  → Job was preempted${NC}"
                break
                ;;
            *)
                echo "  → Unknown status"
                ;;
        esac
        
        PREV_STATUS="$STATUS"
    fi
    
    # Show elapsed time if running
    if [ "$STATUS" = "JOB_STATE_RUNNING" ] && [ -n "$START_TIME" ]; then
        ELAPSED=$(calculate_duration "$START_TIME")
        printf '\r%s' "$(tput el)Elapsed: $ELAPSED"
    fi
    
    # Check if job is terminal
    case "$STATUS" in
        "JOB_STATE_SUCCEEDED"|"JOB_STATE_FAILED"|"JOB_STATE_CANCELLED"|"JOB_STATE_PREEMPTED")
            break
            ;;
    esac
    
    sleep "$POLL_INTERVAL"
done

# Clean up log streaming
if [ -n "$LOG_PID" ]; then
    kill $LOG_PID 2>/dev/null || true
    wait $LOG_PID 2>/dev/null || true
fi

echo ""
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Final Job Status${NC}"
echo -e "${BLUE}========================================${NC}"
get_job_details

# Get output location
OUTPUT_DIR=$(gcloud ai custom-jobs describe "$JOB_ID" \
    --region="$REGION" \
    --format='value(jobSpec.baseOutputDirectory.outputUriPrefix)' 2>/dev/null)

if [ -n "$OUTPUT_DIR" ]; then
    echo ""
    echo "Output Directory:"
    echo "  $OUTPUT_DIR"
    echo ""
    echo "To download outputs:"
    echo "  gsutil -m cp -r $OUTPUT_DIR ./outputs/"
fi

echo ""
echo "Done."
