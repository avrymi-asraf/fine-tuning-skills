#!/bin/bash
#
# cleanup-old-runs.sh - Clean up old ML experiment artifacts
#
# Usage: ./cleanup-old-runs.sh [options] <bucket-uri>
#
# Examples:
#   ./cleanup-old-runs.sh gs://bucket/experiments --older-than=30d
#   ./cleanup-old-runs.sh s3://bucket/checkpoints --keep-last=5 --dry-run
#   ./cleanup-old-runs.sh gs://bucket/logs --all --yes
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
OLDER_THAN=""
KEEP_LAST=0
DRY_RUN=false
CONFIRM=true
DELETE_FAILED=false
DELETE_TEMP=true
EXCLUDE_PATTERNS=()
INCLUDE_PATTERNS=()
SIZE_THRESHOLD=""
SORT_BY="time"  # time or size

usage() {
    cat << EOF
Usage: $0 [OPTIONS] <bucket-uri>

Arguments:
  bucket-uri      Base URI to clean (e.g., gs://bucket/experiments)

Options:
  --older-than=DURATION   Delete runs older than duration (e.g., 30d, 8w, 6m)
  --keep-last=N          Keep N most recent runs, delete rest
  --delete-failed        Delete runs with 'failed' status
  --delete-temp          Delete temp/scratch directories
  --size-threshold=SIZE  Delete runs larger than SIZE (e.g., 100GB)
  --exclude=PATTERN      Exclude paths matching pattern (repeatable)
  --include=PATTERN      Only include paths matching pattern (repeatable)
  --sort-by=FIELD        Sort by 'time' or 'size' (default: time)
  --dry-run              Show what would be deleted without deleting
  --yes                  Skip confirmation prompts
  -h, --help             Show this help

Duration formats:
  Nd = N days
  Nw = N weeks
  Nm = N months
  Ny = N years

Examples:
  # Delete experiments older than 30 days
  $0 gs://bucket/experiments --older-than=30d --dry-run

  # Keep only 10 most recent runs
  $0 gs://bucket/experiments --keep-last=10

  # Delete failed runs only
  $0 gs://bucket/experiments --delete-failed --yes

  # Clean temp files and old logs
  $0 gs://bucket --delete-temp --older-than=7d

  # Delete runs larger than 1TB
  $0 gs://bucket/experiments --size-threshold=1TB --older-than=90d
EOF
    exit 1
}

# Parse arguments
BUCKET_URI=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --older-than=*)
            OLDER_THAN="${1#*=}"
            shift
            ;;
        --keep-last=*)
            KEEP_LAST="${1#*=}"
            shift
            ;;
        --delete-failed)
            DELETE_FAILED=true
            shift
            ;;
        --delete-temp)
            DELETE_TEMP=true
            shift
            ;;
        --no-delete-temp)
            DELETE_TEMP=false
            shift
            ;;
        --size-threshold=*)
            SIZE_THRESHOLD="${1#*=}"
            shift
            ;;
        --exclude=*)
            EXCLUDE_PATTERNS+=("${1#*=}")
            shift
            ;;
        --include=*)
            INCLUDE_PATTERNS+=("${1#*=}")
            shift
            ;;
        --sort-by=*)
            SORT_BY="${1#*=}"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --yes)
            CONFIRM=false
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
            if [[ -z "$BUCKET_URI" ]]; then
                BUCKET_URI="$1"
            fi
            shift
            ;;
    esac
done

# Validate inputs
if [[ -z "$BUCKET_URI" ]]; then
    echo -e "${RED}Error: bucket-uri is required${NC}"
    usage
fi

# Detect provider
PROVIDER=""
if [[ "$BUCKET_URI" == gs://* ]]; then
    PROVIDER="gcs"
elif [[ "$BUCKET_URI" == s3://* ]]; then
    PROVIDER="s3"
elif [[ "$BUCKET_URI" == https://* ]]; then
    PROVIDER="azure"
else
    echo -e "${RED}Error: Unsupported URI: $BUCKET_URI${NC}"
    exit 1
fi

# Parse duration to seconds
parse_duration() {
    local duration="$1"
    local value="${duration%[dwmy]}"
    local unit="${duration: -1}"
    
    case "$unit" in
        d) echo $((value * 86400)) ;;
        w) echo $((value * 604800)) ;;
        m) echo $((value * 2592000)) ;;  # 30 days
        y) echo $((value * 31536000)) ;; # 365 days
        *) echo "$value" ;;
    esac
}

# Parse size to bytes
parse_size() {
    local size="$1"
    local value="${size%[KMGTP]}"
    local unit="${size: -1}"
    
    case "$unit" in
        K) echo $((value * 1024)) ;;
        M) echo $((value * 1024 * 1024)) ;;
        G) echo $((value * 1024 * 1024 * 1024)) ;;
        T) echo $((value * 1024 * 1024 * 1024 * 1024)) ;;
        P) echo $((value * 1024 * 1024 * 1024 * 1024 * 1024)) ;;
        *) echo "$value" ;;
    esac
}

# List runs with metadata
list_runs_gcs() {
    local prefix="${1#gs://}"
    local bucket="${prefix%%/*}"
    local path="${prefix#$bucket/}"
    
    # List directories
    gcloud storage ls "gs://$prefix" 2>/dev/null | while read -r line; do
        if [[ "$line" == */ ]]; then
            local dir_name="${line%/}"
            dir_name="${dir_name##*/}"
            local full_path="${line#gs://$bucket/}"
            
            # Get size and time
            local size=$(gcloud storage du -sh "$line" 2>/dev/null | awk '{print $1}')
            local time=$(gcloud storage ls -l "$line" 2>/dev/null | head -1 | awk '{print $1, $2}')
            
            echo "$dir_name|$line|$size|$time"
        fi
    done
}

list_runs_s3() {
    local prefix="${1#s3://}"
    
    aws s3 ls "$1" 2>/dev/null | grep "PRE" | while read -r line; do
        local dir_name=$(echo "$line" | awk '{print $2}' | sed 's/\/$//')
        local full_path="$1/$dir_name"
        
        # Get size
        local size=$(aws s3 ls --recursive "$full_path" 2>/dev/null | awk '{s+=$3} END {print s}')
        local time=$(aws s3 ls "$1" | grep "PRE $dir_name/" | awk '{print $1, $2}')
        
        echo "$dir_name|$full_path|$size|$time"
    done
}

# Filter runs
should_delete() {
    local name="$1"
    local path="$2"
    local size="$3"
    local mtime="$4"
    
    # Check includes
    if [[ ${#INCLUDE_PATTERNS[@]} -gt 0 ]]; then
        local matched=false
        for pattern in "${INCLUDE_PATTERNS[@]}"; do
            if [[ "$name" == $pattern ]]; then
                matched=true
                break
            fi
        done
        [[ "$matched" == false ]] && return 1
    fi
    
    # Check excludes
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$name" == $pattern ]]; then
            return 1
        fi
    done
    
    # Check age
    if [[ -n "$OLDER_THAN" ]]; then
        local max_age=$(parse_duration "$OLDER_THAN")
        local file_time=$(date -d "$mtime" +%s 2>/dev/null || echo "0")
        local current_time=$(date +%s)
        local age=$((current_time - file_time))
        
        if [[ $age -lt $max_age ]]; then
            return 1
        fi
    fi
    
    # Check size
    if [[ -n "$SIZE_THRESHOLD" ]]; then
        local threshold_bytes=$(parse_size "$SIZE_THRESHOLD")
        # Convert size to bytes (approximate)
        if [[ $size -lt $threshold_bytes ]]; then
            return 1
        fi
    fi
    
    # Check failed status
    if [[ "$DELETE_FAILED" == true ]]; then
        if [[ ! "$name" =~ (failed|error|crash) ]]; then
            return 1
        fi
    fi
    
    return 0
}

# Delete functions
delete_gcs() {
    local path="$1"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN] Would delete: $path${NC}"
        return
    fi
    
    gcloud storage rm -r "$path"
}

delete_s3() {
    local path="$1"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN] Would delete: $path${NC}"
        return
    fi
    
    aws s3 rm --recursive "$path"
}

# Main cleanup logic
main() {
    echo -e "${BLUE}Scanning: $BUCKET_URI${NC}"
    echo "Provider: $PROVIDER"
    echo ""
    
    # Collect runs
    local runs=()
    while IFS='|' read -r name path size mtime; do
        [[ -z "$name" ]] && continue
        runs+=("$name|$path|$size|$mtime")
    done < <(list_runs_$PROVIDER "$BUCKET_URI")
    
    if [[ ${#runs[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No runs found in $BUCKET_URI${NC}"
        exit 0
    fi
    
    echo "Found ${#runs[@]} runs"
    echo ""
    
    # Filter to delete
    local to_delete=()
    local total_size=0
    
    for run in "${runs[@]}"; do
        IFS='|' read -r name path size mtime <<< "$run"
        
        if should_delete "$name" "$path" "$size" "$mtime"; then
            to_delete+=("$run")
            total_size=$((total_size + size))
        fi
    done
    
    # Handle --keep-last
    if [[ $KEEP_LAST -gt 0 ]] && [[ ${#runs[@]} -gt $KEEP_LAST ]]; then
        # Sort by time
        IFS=$'\n' sorted=($(sort -t'|' -k4 <<< "${runs[*]}"))
        unset IFS
        
        # Keep last N, mark rest for deletion
        local to_keep_count=$KEEP_LAST
        local total_count=${#runs[@]}
        local to_delete_count=$((total_count - to_keep_count))
        
        if [[ $to_delete_count -gt 0 ]]; then
            for ((i=0; i<to_delete_count; i++)); do
                local run="${sorted[$i]}"
                IFS='|' read -r name path size mtime <<< "$run"
                
                # Don't double-add if already marked
                local already_marked=false
                for del in "${to_delete[@]}"; do
                    if [[ "$del" == "$run" ]]; then
                        already_marked=true
                        break
                    fi
                done
                
                [[ "$already_marked" == false ]] && to_delete+=("$run")
            done
        fi
    fi
    
    if [[ ${#to_delete[@]} -eq 0 ]]; then
        echo -e "${GREEN}No runs to delete${NC}"
        exit 0
    fi
    
    echo -e "${YELLOW}Runs to delete (${#to_delete[@]}):${NC}"
    echo ""
    
    for run in "${to_delete[@]}"; do
        IFS='|' read -r name path size mtime <<< "$run"
        echo "  - $name"
        echo "    Path: $path"
        echo "    Size: $(numfmt --to=iec $size 2>/dev/null || echo $size)"
        echo "    Modified: $mtime"
        echo ""
    done
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}DRY RUN - No deletions performed${NC}"
        exit 0
    fi
    
    # Confirm
    if [[ "$CONFIRM" == true ]]; then
        echo -e "${RED}This will delete ${#to_delete[@]} runs permanently.${NC}"
        read -p "Continue? (yes/N) " -r
        echo
        if [[ ! $REPLY =~ ^yes$ ]]; then
            echo "Cancelled."
            exit 0
        fi
    fi
    
    # Delete
    echo -e "${BLUE}Deleting...${NC}"
    for run in "${to_delete[@]}"; do
        IFS='|' read -r name path size mtime <<< "$run"
        echo "  Deleting: $name"
        delete_$PROVIDER "$path"
    done
    
    echo ""
    echo -e "${GREEN}Cleanup complete!${NC}"
    echo "Deleted: ${#to_delete[@]} runs"
}

# Handle temp directory cleanup
if [[ "$DELETE_TEMP" == true ]]; then
    echo -e "${BLUE}Cleaning temp directories...${NC}"
    
    temp_patterns=("temp" "scratch" "tmp" "cache" ".temp")
    for pattern in "${temp_patterns[@]}"; do
        temp_uri="$BUCKET_URI/$pattern"
        if list_runs_$PROVIDER "$temp_uri" &>/dev/null; then
            if [[ "$DRY_RUN" == true ]]; then
                echo -e "${YELLOW}[DRY RUN] Would delete temp: $temp_uri${NC}"
            else
                echo "Deleting: $temp_uri"
                delete_$PROVIDER "$temp_uri" || true
            fi
        fi
    done
    echo ""
fi

main
