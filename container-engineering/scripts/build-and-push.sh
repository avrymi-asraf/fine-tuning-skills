#!/bin/bash
# build-and-push.sh - Build optimized ML container and push to Artifact Registry
#
# Usage: PROJECT_ID=my-project REGION=us-central1 ./build-and-push.sh [tag]

set -euo pipefail

usage() {
    echo "Usage: PROJECT_ID=<project> ./build-and-push.sh [tag]"
    echo ""
    echo "Builds and pushes an optimized ML container to Artifact Registry."
    echo ""
    echo "Options:"
    echo "  [tag]         Image tag (default: latest)"
    echo "  --help, -h    Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  PROJECT_ID    (Required) Google Cloud Project ID"
    echo "  REGION        (Optional) GCP Region (default: us-central1)"
    echo "  REPO_NAME     (Optional) Artifact Registry repo name (default: ml-containers)"
    echo "  IMAGE_NAME    (Optional) Target image name (default: training-gpu)"
    echo "  DOCKERFILE    (Optional) Path to Dockerfile (default: Dockerfile)"
    exit 0
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

if [[ $# -eq 0 && -z "${PROJECT_ID:-}" ]]; then
    usage
fi

# Configuration
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || echo '')}"
REGION="${REGION:-us-central1}"
REPO_NAME="${REPO_NAME:-ml-containers}"
IMAGE_NAME="${IMAGE_NAME:-training-gpu}"
TAG="${1:-latest}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Validate prerequisites
check_prerequisites() {
    if [[ -z "$PROJECT_ID" ]]; then
        echo -e "${RED}Error: PROJECT_ID not set${NC}"
        echo "Set with: export PROJECT_ID=your-project-id"
        exit 1
    fi

    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: docker not found${NC}"
        exit 1
    fi

    if ! command -v gcloud &> /dev/null; then
        echo -e "${RED}Error: gcloud not found${NC}"
        exit 1
    fi

    # Check Docker BuildKit
    if [[ -z "${DOCKER_BUILDKIT:-}" ]]; then
        export DOCKER_BUILDKIT=1
        echo -e "${YELLOW}Enabled DOCKER_BUILDKIT=1${NC}"
    fi
}

# Configure Docker auth for Artifact Registry
configure_auth() {
    echo "=== Configuring Artifact Registry auth ==="
    
    # Check if already authenticated
    if ! gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet 2>/dev/null; then
        echo "Authenticating with Artifact Registry..."
        gcloud auth configure-docker "${REGION}-docker.pkg.dev"
    fi
}

# Build the image with optimizations
build_image() {
    local artifact_uri="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${TAG}"
    local cache_uri="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:cache"
    
    echo ""
    echo "=== Building Image ==="
    echo "Image: ${artifact_uri}"
    echo "Platform: linux/amd64"
    echo "Dockerfile: ${DOCKERFILE}"
    echo ""
    
    # Try to pull cache image for layer caching
    echo "Attempting to pull cache image..."
    docker pull "${cache_uri}" 2>/dev/null || echo "No cache image found (will build fresh)"
    
    # Build with layer caching
    docker build \
        --platform linux/amd64 \
        --cache-from "${cache_uri}" \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        -t "${artifact_uri}" \
        -t "${cache_uri}" \
        -f "${DOCKERFILE}" \
        --progress=auto \
        .
    
    echo ""
    echo -e "${GREEN}✓ Build complete${NC}"
    
    # Show image size
    local size
    size=$(docker images --format "{{.Size}}" "${artifact_uri}")
    echo "Image size: ${size}"
}

# Push to Artifact Registry
push_image() {
    local artifact_uri="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${TAG}"
    local cache_uri="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:cache"
    
    echo ""
    echo "=== Pushing to Artifact Registry ==="
    
    echo "Pushing ${TAG}..."
    docker push "${artifact_uri}"
    
    echo "Pushing cache tag..."
    docker push "${cache_uri}"
    
    echo ""
    echo -e "${GREEN}✓ Push complete${NC}"
    echo ""
    echo "Image URI: ${artifact_uri}"
    echo ""
    echo "Use in Vertex AI:"
    echo "  gcloud ai custom-jobs create \\"
    echo "    --region=${REGION} \\"
    echo "    --display-name=training-job \\"
    echo "    --worker-pool-spec=machine-type=n1-standard-8,accelerator-type=NVIDIA_TESLA_T4,accelerator-count=1,container-image-uri=${artifact_uri}"
}

# Tag for additional registries
tag_for_registries() {
    if [[ "${TAG_DOCKER_HUB:-}" == "true" ]]; then
        local dockerhub_user="${DOCKERHUB_USER:-}"
        if [[ -n "$dockerhub_user" ]]; then
            local artifact_uri="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${TAG}"
            local dockerhub_uri="${dockerhub_user}/${IMAGE_NAME}:${TAG}"
            
            echo ""
            echo "=== Tagging for Docker Hub ==="
            docker tag "${artifact_uri}" "${dockerhub_uri}"
            docker push "${dockerhub_uri}"
            echo -e "${GREEN}✓ Pushed to Docker Hub${NC}"
        fi
    fi
}

# Main execution
main() {
    echo "========================================"
    echo "  ML Container Build & Push"
    echo "========================================"
    echo ""
    
    check_prerequisites
    configure_auth
    build_image
    push_image
    tag_for_registries
    
    echo ""
    echo "========================================"
    echo -e "${GREEN}  All done!${NC}"
    echo "========================================"
}

main "$@"