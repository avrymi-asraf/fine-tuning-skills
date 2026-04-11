#!/bin/bash
# Purpose: Sync a local directory with GCS (wrapper around gcloud storage rsync)
# Usage:   ./sync-directory.sh <source> <destination>
#
# Examples:
#   ./sync-directory.sh ./outputs gs://bucket/outputs
#   ./sync-directory.sh gs://bucket/checkpoints ./checkpoints
#   ./sync-directory.sh --delete ./data gs://bucket/data

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat >&2 << 'EOF'
Usage: sync-directory.sh [options] <source> <destination>

Arguments:
  source          Local directory or gs:// URI
  destination     Local directory or gs:// URI

Options:
  --delete              Delete destination files not present in source
  --exclude=PATTERN     Exclude files matching glob pattern (repeatable)
  --dry-run             Show what would be synced
  -h, --help            Show this help

At least one of source/destination must be a gs:// URI.
EOF
    exit 1
}

DELETE=false
DRY_RUN=false
EXCLUDES=()
SOURCE=""
DESTINATION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --delete)       DELETE=true; shift ;;
        --exclude=*)    EXCLUDES+=("${1#*=}"); shift ;;
        --dry-run)      DRY_RUN=true; shift ;;
        -h|--help)      usage ;;
        -*)             echo "Error: unknown option $1" >&2; usage ;;
        *)
            if [[ -z "$SOURCE" ]]; then
                SOURCE="$1"
            elif [[ -z "$DESTINATION" ]]; then
                DESTINATION="$1"
            else
                echo "Error: too many arguments" >&2; usage
            fi
            shift ;;
    esac
done

[[ -z "$SOURCE" ]] || [[ -z "$DESTINATION" ]] && { echo "Error: source and destination are required" >&2; usage; }

FLAGS="-r"
[[ "$DELETE" == true ]] && FLAGS="$FLAGS --delete-unmatched-destination-objects"
[[ "$DRY_RUN" == true ]] && FLAGS="$FLAGS --dry-run"

for pattern in "${EXCLUDES[@]+"${EXCLUDES[@]}"}"; do
    FLAGS="$FLAGS --exclude-name-pattern=$pattern"
done

echo "Syncing: $SOURCE → $DESTINATION" >&2

# shellcheck disable=SC2086
gcloud storage rsync $FLAGS "$SOURCE" "$DESTINATION"

if [[ "$DRY_RUN" == false ]]; then
    echo "Sync complete." >&2
fi
