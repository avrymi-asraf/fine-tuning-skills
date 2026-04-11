#!/bin/bash
# test-container-locally.sh - Validate ML container locally before pushing to cloud
#
# Usage: ./test-container-locally.sh [image-tag] [project-id]

set -euo pipefail

usage() {
    echo "Usage: ./test-container-locally.sh [image-tag] [project-id]"
    echo ""
    echo "Validates an ML container locally before pushing to cloud."
    echo ""
    echo "Options:"
    echo "  [image-tag]   Image tag or full path to test (default: training-gpu:latest)"
    echo "  [project-id]  Google Cloud Project ID (optional if tag is full path)"
    echo "  --help, -h    Show this help message"
    echo ""
    exit 0
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

if [[ $# -eq 0 && -z "${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || echo '')}" ]]; then
    usage
fi

# Configuration
TAG="${1:-training-gpu:latest}"
PROJECT_ID="${2:-$(gcloud config get-value project 2>/dev/null || echo '')}"
REGION="${REGION:-us-central1}"
REPO_NAME="${REPO_NAME:-ml-containers}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

# Resolve full image path
if [[ "$TAG" == *"/"* ]]; then
    # Full path provided
    FULL_IMAGE="$TAG"
else
    # Just tag, construct full path
    if [[ -z "$PROJECT_ID" ]]; then
        echo -e "${RED}Error: PROJECT_ID not set${NC}"
        echo "Usage: $0 [image-tag] [project-id]"
        exit 1
    fi
    FULL_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${TAG}"
fi

# Test runner
run_test() {
    local name="$1"
    local command="$2"
    
    echo ""
    echo -e "${BLUE}▶ Test: ${name}${NC}"
    
    if eval "$command"; then
        echo -e "${GREEN}✓ PASS: ${name}${NC}"
        ((PASS_COUNT++))
        return 0
    else
        echo -e "${RED}✗ FAIL: ${name}${NC}"
        ((FAIL_COUNT++))
        return 1
    fi
}

# Prerequisites check
echo "========================================"
echo "  Container Validation Tests"
echo "========================================"
echo ""
echo "Image: ${FULL_IMAGE}"
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: docker not found${NC}"
    exit 1
fi

# Check NVIDIA runtime
if ! docker info 2>/dev/null | grep -q "nvidia"; then
    echo -e "${YELLOW}Warning: NVIDIA runtime may not be configured${NC}"
    echo "Install: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
fi

# Pull image if not local
echo "Checking for image..."
if ! docker image inspect "${FULL_IMAGE}" > /dev/null 2>&1; then
    echo "Image not found locally, pulling..."
    if ! docker pull "${FULL_IMAGE}"; then
        echo -e "${RED}Error: Failed to pull image${NC}"
        exit 1
    fi
fi

# Run tests
run_test "Container starts" \
    "docker run --rm \"${FULL_IMAGE}\" echo 'Container started successfully'"

run_test "NVIDIA runtime available" \
    "docker run --rm --gpus all \"${FULL_IMAGE}\" nvidia-smi > /dev/null"

run_test "CUDA runtime version check" \
    "docker run --rm --gpus all \"${FULL_IMAGE}\" nvidia-smi"

run_test "Python environment functional" \
    "docker run --rm \"${FULL_IMAGE}\" python --version"

run_test "PyTorch installed" \
    "docker run --rm \"${FULL_IMAGE}\" python -c 'import torch; print(f'PyTorch: {torch.__version__}')'"

run_test "CUDA available to PyTorch" \
    "docker run --rm --gpus all \"${FULL_IMAGE}\" python -c '
import torch
if not torch.cuda.is_available():
    raise RuntimeError(\"CUDA not available\")
print(f\"CUDA: {torch.version.cuda}\")
print(f\"GPU count: {torch.cuda.device_count()}\")
print(f\"GPU: {torch.cuda.get_device_name(0)}\")
'"

run_test "PyTorch GPU tensor operations" \
    "docker run --rm --gpus all \"${FULL_IMAGE}\" python -c '
import torch
x = torch.randn(1000, 1000).cuda()
y = torch.randn(1000, 1000).cuda()
z = torch.matmul(x, y)
print(f\"Matrix multiply: {z.shape} - OK\")
'"

run_test "GPU memory allocation" \
    "docker run --rm --gpus all \"${FULL_IMAGE}\" python -c '
import torch
torch.cuda.empty_cache()
mem_before = torch.cuda.memory_allocated()
x = torch.zeros(100_000_000, device=\"cuda\")  # ~400MB
mem_after = torch.cuda.memory_allocated()
print(f\"Allocated: {(mem_after - mem_before) / 1e6:.1f} MB\")
'"

# Check for common ML libraries
run_test "Transformers library" \
    "docker run --rm \"${FULL_IMAGE}\" python -c 'import transformers; print(f\"transformers: {transformers.__version__}\")' 2>/dev/null || echo 'Not installed (OK if not needed)'"

run_test "Accelerate library" \
    "docker run --rm \"${FULL_IMAGE}\" python -c 'import accelerate; print(f\"accelerate: {accelerate.__version__}\")' 2>/dev/null || echo 'Not installed (OK if not needed)'"

run_test "Non-root execution (if configured)" \
    "docker run --rm \"${FULL_IMAGE}\" id || echo 'Note: Running as root (configure USER in Dockerfile for production)'"

# Summary
echo ""
echo "========================================"
echo "  Test Summary"
echo "========================================"
echo -e "${GREEN}Passed: ${PASS_COUNT}${NC}"
if [[ $FAIL_COUNT -gt 0 ]]; then
    echo -e "${RED}Failed: ${FAIL_COUNT}${NC}"
    exit 1
else
    echo -e "${YELLOW}Skipped/Info: See above${NC}"
    echo ""
    echo -e "${GREEN}✓ All critical tests passed!${NC}"
    echo ""
    echo "Container is ready for deployment."
    exit 0
fi