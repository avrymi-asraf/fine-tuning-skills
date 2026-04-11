#!/bin/bash
# Purpose: Download ML model artifacts from GCS with optional verification
# Usage:   ./download-model.sh <gs://uri> [local-path]
#
# Examples:
#   ./download-model.sh gs://bucket/models/llama-7b ./models/llama-7b
#   ./download-model.sh --verify --checksum=abc123 gs://bucket/model.pt ./model.pt
#   ./download-model.sh --extract gs://bucket/models/archive.tar.gz ./models/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat >&2 << 'EOF'
Usage: download-model.sh [options] <gs://uri> [local-path]

Arguments:
  gs://uri          Source GCS URI
  local-path        Destination (default: basename of URI in current dir)

Options:
  --verify              Verify checksum after download
  --checksum=HASH       Expected MD5 (32 chars) or SHA256 checksum
  --extract             Extract tar.gz/zip archives after download
  --force               Overwrite existing local files without prompting
  --dry-run             Show what would be downloaded
  -h, --help            Show this help
EOF
    exit 1
}

VERIFY=false
CHECKSUM=""
EXTRACT=false
FORCE=false
DRY_RUN=false
GCS_URI=""
LOCAL_PATH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --verify)       VERIFY=true; shift ;;
        --checksum=*)   CHECKSUM="${1#*=}"; VERIFY=true; shift ;;
        --extract)      EXTRACT=true; shift ;;
        --force)        FORCE=true; shift ;;
        --dry-run)      DRY_RUN=true; shift ;;
        -h|--help)      usage ;;
        -*)             echo "Error: unknown option $1" >&2; usage ;;
        *)
            if [[ -z "$GCS_URI" ]]; then
                GCS_URI="$1"
            elif [[ -z "$LOCAL_PATH" ]]; then
                LOCAL_PATH="$1"
            else
                echo "Error: too many arguments" >&2; usage
            fi
            shift ;;
    esac
done

[[ -z "$GCS_URI" ]] && { echo "Error: gs://uri is required" >&2; usage; }
[[ "$GCS_URI" != gs://* ]] && { echo "Error: source must start with gs://" >&2; exit 1; }
[[ -z "$LOCAL_PATH" ]] && LOCAL_PATH="$(basename "$GCS_URI")"

if [[ -e "$LOCAL_PATH" ]] && [[ "$FORCE" == false ]]; then
    echo "Destination already exists: $LOCAL_PATH" >&2
    read -p "Overwrite? (y/N) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && { echo "Cancelled." >&2; exit 0; }
fi

if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY RUN] Would download: $GCS_URI → $LOCAL_PATH" >&2
    exit 0
fi

echo "Downloading $GCS_URI → $LOCAL_PATH" >&2
mkdir -p "$(dirname "$LOCAL_PATH")"
gcloud storage cp -r "$GCS_URI" "$LOCAL_PATH"

# Verify checksum
if [[ "$VERIFY" == true ]] && [[ -f "$LOCAL_PATH" ]]; then
    if [[ -n "$CHECKSUM" ]]; then
        if [[ ${#CHECKSUM} -eq 32 ]]; then
            ACTUAL=$(md5sum "$LOCAL_PATH" | cut -d' ' -f1)
        else
            ACTUAL=$(sha256sum "$LOCAL_PATH" | cut -d' ' -f1)
        fi
        if [[ "$ACTUAL" != "$CHECKSUM" ]]; then
            echo "Checksum mismatch! Expected: $CHECKSUM, Got: $ACTUAL" >&2
            exit 1
        fi
        echo "Checksum verified: $ACTUAL" >&2
    else
        echo "Warning: --verify used without --checksum, skipping" >&2
    fi
fi

# Extract archive
if [[ "$EXTRACT" == true ]] && [[ -f "$LOCAL_PATH" ]]; then
    EXTRACT_DIR="$(dirname "$LOCAL_PATH")"
    case "$LOCAL_PATH" in
        *.tar.gz|*.tgz)  tar -xzf "$LOCAL_PATH" -C "$EXTRACT_DIR" ;;
        *.tar.bz2)       tar -xjf "$LOCAL_PATH" -C "$EXTRACT_DIR" ;;
        *.zip)           unzip -q "$LOCAL_PATH" -d "$EXTRACT_DIR" ;;
        *)               echo "Unknown archive format: $LOCAL_PATH" >&2 ;;
    esac
    echo "Extracted to: $EXTRACT_DIR" >&2
fi

SIZE=$(du -sh "$LOCAL_PATH" 2>/dev/null | cut -f1)
echo "Download complete: $LOCAL_PATH ($SIZE)" >&2
