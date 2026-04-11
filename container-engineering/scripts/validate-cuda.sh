#!/bin/bash
# validate-cuda.sh - Check CUDA compatibility between host and container requirements
#
# Usage: ./validate-cuda.sh [required_cuda_version]

set -euo pipefail

usage() {
    echo "Usage: ./validate-cuda.sh [required_cuda_version]"
    echo ""
    echo "Check CUDA compatibility between host and container requirements."
    echo ""
    echo "Options:"
    echo "  [required_cuda_version]  Optional CUDA version to check (e.g., 12.4)"
    echo "  --help, -h               Show this help message"
    echo ""
    exit 0
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
    usage
fi

REQUIRED_CUDA="${1:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo "  CUDA Compatibility Validator"
echo "========================================"
echo ""

# Check if nvidia-smi is available
check_host_driver() {
    echo -e "${BLUE}Host System:${NC}"
    
    if ! command -v nvidia-smi &> /dev/null; then
        echo -e "${RED}✗ nvidia-smi not found${NC}"
        echo "  Install NVIDIA drivers: https://www.nvidia.com/drivers"
        return 1
    fi
    
    echo -e "${GREEN}✓ NVIDIA driver installed${NC}"
    
    # Get driver version
    local driver_version
    driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)
    echo "  Driver Version: ${driver_version}"
    
    # Get CUDA version from driver
    local cuda_version
    cuda_version=$(nvidia-smi | grep "CUDA Version" | sed 's/.*CUDA Version: \([0-9.]*\).*/\1/')
    echo "  Maximum CUDA Version Supported: ${cuda_version}"
    
    # Get GPU info
    local gpu_name
    gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
    echo "  GPU: ${gpu_name}"
    
    local compute_cap
    compute_cap=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1)
    echo "  Compute Capability: ${compute_cap}"
    
    # Map compute capability to architectures
    case "$compute_cap" in
        10.0) echo "  Architecture: Blackwell (B100/B200)" ;;
        9.0)  echo "  Architecture: Hopper (H100)" ;;
        8.9)  echo "  Architecture: Ada Lovelace (RTX 40-series, L4)" ;;
        8.6)  echo "  Architecture: Ampere (RTX 30-series, A40)" ;;
        8.0)  echo "  Architecture: Ampere (A100)" ;;
        7.5)  echo "  Architecture: Turing (RTX 20-series, T4)" ;;
        7.0)  echo "  Architecture: Volta (V100)" ;;
        6.*)  echo "  Architecture: Pascal (GTX 10-series, P100)" ;;
        *)    echo "  Architecture: Older (check NVIDIA docs)" ;;
    esac
    
    echo ""
    echo "${cuda_version}"
}

# Check minimum driver for CUDA version
get_min_driver() {
    local cuda_ver="$1"
    case "$cuda_ver" in
        12.8|12.6|12.4|12.3|12.2|12.1|12.0)
            echo "525.60.13"
            ;;
        11.8|11.7|11.6|11.5|11.4)
            echo "450.80.02"
            ;;
        11.0|11.1|11.2|11.3)
            echo "450.36.06"
            ;;
        10.*)
            echo "410.48"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Validate container CUDA against host
validate_compatibility() {
    local host_cuda="$1"
    local container_cuda="$2"
    
    echo -e "${BLUE}Compatibility Check:${NC}"
    echo "  Host max CUDA: ${host_cuda}"
    echo "  Container CUDA: ${container_cuda}"
    
    # Simple version comparison (assumes X.Y format)
    local host_major host_minor
    local cont_major cont_minor
    
    host_major=$(echo "$host_cuda" | cut -d. -f1)
    host_minor=$(echo "$host_cuda" | cut -d. -f2)
    cont_major=$(echo "$container_cuda" | cut -d. -f1)
    cont_minor=$(echo "$container_cuda" | cut -d. -f2)
    
    if [[ "$cont_major" -lt "$host_major" ]] || \
       ([[ "$cont_major" -eq "$host_major" ]] && [[ "$cont_minor" -le "$host_minor" ]]); then
        echo -e "${GREEN}✓ Compatible: Container CUDA ${container_cuda} ≤ Host max ${host_cuda}${NC}"
        return 0
    else
        echo -e "${RED}✗ INCOMPATIBLE: Container CUDA ${container_cuda} > Host max ${host_cuda}${NC}"
        echo "  Solutions:"
        echo "    1. Use a container with CUDA ≤ ${host_cuda}"
        echo "    2. Upgrade host NVIDIA driver to support CUDA ${container_cuda}"
        return 1
    fi
}

# Recommend CUDA version based on GPU
recommend_cuda() {
    local compute_cap="$1"
    
    echo -e "${BLUE}Recommended CUDA Versions:${NC}"
    
    case "$compute_cap" in
        10.0)
            echo "  CUDA 12.8+ (Blackwell requires CUDA 12.0+)"
            ;;
        9.0)
            echo "  CUDA 11.8+ (Hopper supported since 11.8)"
            echo "  CUDA 12.x recommended"
            ;;
        8.9|8.6|8.0)
            echo "  CUDA 11.8+ or 12.x (Ampere/Ada)"
            ;;
        7.5|7.0)
            echo "  CUDA 10.0+ (Turing/Volta)"
            echo "  CUDA 11.8 or 12.x recommended"
            ;;
        *)
            echo "  CUDA 11.8 should work for most older GPUs"
            ;;
    esac
}

# Main execution
main() {
    local host_cuda
    host_cuda=$(check_host_driver) || exit 1
    
    # Get compute capability
    local compute_cap
    compute_cap=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1)
    recommend_cuda "$compute_cap"
    
    echo ""
    
    # If a specific CUDA version was requested, validate it
    if [[ -n "$REQUIRED_CUDA" ]]; then
        validate_compatibility "$host_cuda" "$REQUIRED_CUDA"
    else
        echo -e "${YELLOW}Tip: Run with a CUDA version to check compatibility${NC}"
        echo "  Example: $0 12.4"
        echo ""
        echo "Common CUDA versions for ML:"
        echo "  12.4 - Latest stable, good for RTX 40-series, A100, H100"
        echo "  12.1 - Vertex AI compatible"
        echo "  11.8 - Widest compatibility"
    fi
}

main "$@"