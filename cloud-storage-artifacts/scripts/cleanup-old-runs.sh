#!/bin/bash
# Purpose: Clean up old ML experiment directories in GCS
# Usage:   ./cleanup-old-runs.sh <gs://uri> --older-than=30d
#
# Examples:
#   ./cleanup-old-runs.sh gs://bucket/experiments --older-than=30d --dry-run
#   ./cleanup-old-runs.sh gs://bucket/experiments --keep-last=5
#   ./cleanup-old-runs.sh gs://bucket/checkpoints --older-than=7d --yes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat >&2 << 'EOF'
Usage: cleanup-old-runs.sh [options] <gs://uri>

Arguments:
  gs://uri              Base GCS path to scan for subdirectories

Options:
  --older-than=DURATION Delete directories older than duration (e.g. 7d, 4w, 3m)
  --keep-last=N         Keep N most recent directories, delete the rest
  --dry-run             List what would be deleted without deleting
  --yes                 Skip confirmation prompt
  -h, --help            Show this help

Duration: Nd=days, Nw=weeks, Nm=months (30d). At least one of --older-than
or --keep-last is required.
EOF
    exit 1
}

BUCKET_URI=""
OLDER_THAN=""
KEEP_LAST=0
DRY_RUN=false
AUTO_YES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --older-than=*) OLDER_THAN="${1#*=}"; shift ;;
        --keep-last=*)  KEEP_LAST="${1#*=}"; shift ;;
        --dry-run)      DRY_RUN=true; shift ;;
        --yes)          AUTO_YES=true; shift ;;
        -h|--help)      usage ;;
        -*)             echo "Error: unknown option $1" >&2; usage ;;
        *)
            [[ -z "$BUCKET_URI" ]] && BUCKET_URI="$1"
            shift ;;
    esac
done

[[ -z "$BUCKET_URI" ]] && { echo "Error: gs://uri is required" >&2; usage; }
[[ "$BUCKET_URI" != gs://* ]] && { echo "Error: URI must start with gs://" >&2; exit 1; }
[[ -z "$OLDER_THAN" ]] && [[ "$KEEP_LAST" -eq 0 ]] && { echo "Error: specify --older-than or --keep-last" >&2; usage; }

# Parse duration string to seconds
parse_duration() {
    local val="${1%[dwm]}"
    case "${1: -1}" in
        d) echo $((val * 86400)) ;;
        w) echo $((val * 604800)) ;;
        m) echo $((val * 2592000)) ;;
        *) echo "$val" ;;
    esac
}

# List immediate subdirectories with their creation times
echo "Scanning $BUCKET_URI ..." >&2
DIRS=()
while IFS= read -r line; do
    [[ "$line" == */ ]] && DIRS+=("$line")
done < <(gcloud storage ls "$BUCKET_URI/" 2>/dev/null)

if [[ ${#DIRS[@]} -eq 0 ]]; then
    echo "No subdirectories found in $BUCKET_URI" >&2
    exit 0
fi
echo "Found ${#DIRS[@]} directories" >&2

# Collect directory info: path and newest object timestamp
declare -A DIR_TIMES
NOW=$(date +%s)

for dir in "${DIRS[@]}"; do
    # Get the most recent object timestamp in this directory
    LATEST=$(gcloud storage ls -l -r "$dir" 2>/dev/null | grep -v "TOTAL:" | tail -1 | awk '{print $1}')
    if [[ -n "$LATEST" ]]; then
        DIR_TIMES["$dir"]=$(date -d "$LATEST" +%s 2>/dev/null || echo "0")
    else
        DIR_TIMES["$dir"]=0
    fi
done

# Build deletion list
TO_DELETE=()

if [[ -n "$OLDER_THAN" ]]; then
    MAX_AGE=$(parse_duration "$OLDER_THAN")
    for dir in "${DIRS[@]}"; do
        AGE=$((NOW - ${DIR_TIMES[$dir]}))
        if [[ $AGE -gt $MAX_AGE ]]; then
            TO_DELETE+=("$dir")
        fi
    done
fi

if [[ "$KEEP_LAST" -gt 0 ]] && [[ ${#DIRS[@]} -gt $KEEP_LAST ]]; then
    # Sort directories by timestamp (newest first), mark oldest for deletion
    SORTED=($(for dir in "${DIRS[@]}"; do echo "${DIR_TIMES[$dir]} $dir"; done | sort -rn | awk '{print $2}'))
    for ((i=KEEP_LAST; i<${#SORTED[@]}; i++)); do
        # Avoid duplicates
        ALREADY=false
        for d in "${TO_DELETE[@]+"${TO_DELETE[@]}"}"; do
            [[ "$d" == "${SORTED[$i]}" ]] && ALREADY=true
        done
        [[ "$ALREADY" == false ]] && TO_DELETE+=("${SORTED[$i]}")
    done
fi

if [[ ${#TO_DELETE[@]} -eq 0 ]]; then
    echo "Nothing to delete." >&2
    exit 0
fi

echo "" >&2
echo "Directories to delete (${#TO_DELETE[@]}):" >&2
for dir in "${TO_DELETE[@]}"; do
    echo "  $dir" >&2
done

if [[ "$DRY_RUN" == true ]]; then
    echo "" >&2
    echo "[DRY RUN] No deletions performed." >&2
    exit 0
fi

if [[ "$AUTO_YES" == false ]]; then
    echo "" >&2
    read -p "Delete ${#TO_DELETE[@]} directories permanently? (yes/N) " -r
    [[ ! "$REPLY" =~ ^yes$ ]] && { echo "Cancelled." >&2; exit 0; }
fi

for dir in "${TO_DELETE[@]}"; do
    echo "Deleting: $dir" >&2
    gcloud storage rm -r "$dir"
done

echo "Cleanup complete — deleted ${#TO_DELETE[@]} directories." >&2
