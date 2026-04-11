# Container Engineering Cheatsheet

Quick commands for ML container workflows.

---

## Docker Commands

### Build

```bash
# Basic build
docker build -t myimage:latest .

# Build with specific Dockerfile
docker build -t myimage:latest -f Dockerfile.gpu .

# Multi-platform build (for cloud)
docker build --platform linux/amd64 -t myimage:latest .

# Build with BuildKit (faster, required for cache mounts)
DOCKER_BUILDKIT=1 docker build -t myimage:latest .

# Build with layer caching from registry
docker build \
  --cache-from myregistry/myimage:cache \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  -t myimage:latest .
```

### Run with GPU

```bash
# Basic GPU access
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi

# Specific GPU(s)
docker run --rm --gpus '"device=0,1"' nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi

# All GPUs with capabilities
docker run --rm --gpus all,capabilities=compute,utility nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi

# Interactive with GPU
docker run -it --rm --gpus all myimage:latest bash

# Mount local directory
docker run -it --rm --gpus all -v $(pwd):/workspace myimage:latest bash
```

### Inspect & Debug

```bash
# Image size
docker images myimage:latest --format "{{.Size}}"

# History (layers)
docker history myimage:latest

# Dive into image
docker run -it --rm --entrypoint bash myimage:latest

# Check installed packages
docker run --rm myimage:latest pip list

# Export filesystem
docker export $(docker create myimage:latest) -o myimage.tar
```

### Clean Up

```bash
# Remove dangling images
docker image prune

# Remove all unused images
docker image prune -a

# Remove specific image
docker rmi myimage:latest

# Clean build cache
docker builder prune

# Nuclear option (use with caution)
docker system prune -a
```

---

## Artifact Registry

### Setup

```bash
# Authenticate Docker
gcloud auth configure-docker us-central1-docker.pkg.dev

# Create repository
gcloud artifacts repositories create ml-containers \
  --repository-format=docker \
  --location=us-central1 \
  --description="ML training containers"
```

### Push/Pull

```bash
# Tag for Artifact Registry
docker tag myimage:latest us-central1-docker.pkg.dev/PROJECT/ml-containers/myimage:latest

# Push
docker push us-central1-docker.pkg.dev/PROJECT/ml-containers/myimage:latest

# Pull
docker pull us-central1-docker.pkg.dev/PROJECT/ml-containers/myimage:latest

# List images
gcloud artifacts docker images list us-central1-docker.pkg.dev/PROJECT/ml-containers

# Delete image
gcloud artifacts docker images delete us-central1-docker.pkg.dev/PROJECT/ml-containers/myimage:latest --delete-tags
```

---

## Cloud Build

### Submit Build

```bash
# Using cloudbuild.yaml
gcloud builds submit --config cloudbuild.yaml

# Inline build
gcloud builds submit --tag us-central1-docker.pkg.dev/PROJECT/ml-containers/myimage:latest

# With substitutions
gcloud builds submit \
  --config cloudbuild.yaml \
  --substitutions=_REGION=us-central1,_IMAGE=myimage

# Build specific machine type
gcloud builds submit \
  --config cloudbuild.yaml \
  --machine-type=e2-highcpu-32
```

### Cloudbuild.yaml Template

```yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '--cache-from'
      - '${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO}/${_IMAGE}:cache'
      - '--build-arg'
      - 'BUILDKIT_INLINE_CACHE=1'
      - '-t'
      - '${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO}/${_IMAGE}:$COMMIT_SHA'
      - '-t'
      - '${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO}/${_IMAGE}:latest'
      - '.'
    env: ['DOCKER_BUILDKIT=1']

  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', '${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO}/${_IMAGE}', '--all-tags']

options:
  machineType: 'N1_HIGHCPU_32'
  diskSizeGb: '100'
  logging: CLOUD_LOGGING_ONLY

substitutions:
  _REGION: us-central1
  _REPO: ml-containers
  _IMAGE: training-gpu

images:
  - '${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO}/${_IMAGE}:$COMMIT_SHA'
  - '${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO}/${_IMAGE}:latest'
```

---

## NVIDIA Container Toolkit

### Install

```bash
# Ubuntu/Debian
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### Verify

```bash
# Check runtime
docker info | grep nvidia

# Test GPU access
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi

# Check toolkit version
nvidia-ctk --version
```

---

## uv (Fast Python Package Manager)

### Dockerfile Patterns

```dockerfile
# Install uv
COPY --from=ghcr.io/astral-sh/uv:0.5 /uv /bin/uv

# Environment variables
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_PREFERENCE=only-managed

# Install Python
RUN uv python install 3.11

# Create venv
RUN uv venv /opt/venv --python 3.11

# Install packages
RUN uv pip install --python /opt/venv/bin/python torch transformers
```

### Commands

```bash
# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install Python
uv python install 3.11

# Create venv
uv venv .venv --python 3.11

# Install packages
uv pip install torch transformers

# With specific index
uv pip install torch --index-url https://download.pytorch.org/whl/cu124

# Lockfile
uv pip compile requirements.in -o requirements.txt
uv pip sync requirements.txt

# Faster: compile bytecode
UV_COMPILE_BYTECODE=1 uv pip install torch
```

---

## Multi-Stage Build Optimization

### Image Size Comparison

| Approach | Size | Build Time |
|---------|------|------------|
| Single stage devel | ~8GB | 10 min |
| Single stage runtime | ~5GB | 10 min |
| Multi-stage pip | ~2GB | 12 min |
| Multi-stage uv | ~1.5GB | 5 min |

### Dockerfile Layer Cache Strategy

```dockerfile
# 1. System dependencies (rarely change)
RUN apt-get update && apt-get install -y libgomp1

# 2. Heavy frameworks (change monthly)
RUN uv pip install torch==2.5.1

# 3. Requirements (change weekly)
COPY requirements.txt .
RUN uv pip install -r requirements.txt

# 4. Source code (changes daily)
COPY src/ ./src/
```

---

## Vertex AI Integration

### Environment Variables

| Variable | Description |
|----------|-------------|
| `AIP_MODEL_DIR` | GCS path for model output |
| `AIP_TENSORBOARD_LOG_DIR` | GCS path for TensorBoard |
| `AIP_CHECKPOINT_DIR` | GCS path for checkpoints |
| `AIP_DATA_DIR` | GCS path for input data |

### Submit Job

```bash
# With custom container
gcloud ai custom-jobs create \
  --region=us-central1 \
  --display-name=training-job \
  --worker-pool-spec=\
    machine-type=n1-standard-8,\
    accelerator-type=NVIDIA_TESLA_T4,\
    accelerator-count=1,\
    container-image-uri=us-central1-docker.pkg.dev/PROJECT/ml-containers/myimage:latest \
  --args=--epochs=3 \
  --args=--batch-size=16
```

### Accelerator Types

| Type | GPU | Memory |
|------|-----|--------|
| NVIDIA_TESLA_T4 | T4 | 16GB |
| NVIDIA_TESLA_V100 | V100 | 16GB |
| NVIDIA_TESLA_A100 | A100 | 40GB |
| NVIDIA_L4 | L4 | 24GB |
| NVIDIA_A100_80GB | A100 | 80GB |

---

## Debugging

### Container Won't Start

```bash
# Check logs
docker logs container_name

# Interactive debug
docker run -it --rm --gpus all --entrypoint bash myimage:latest

# Check environment
docker run --rm myimage:latest env
```

### GPU Not Available

```bash
# Host GPU check
nvidia-smi

# Container GPU check
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi

# Check runtime
docker info | grep -i nvidia

# Verify toolkit
nvidia-ctk runtime configure --runtime=docker --dry-run
```

### PyTorch CUDA Issues

```python
# Inside container
import torch

# Check CUDA available
print(f"CUDA available: {torch.cuda.is_available()}")

# Check CUDA version
print(f"CUDA version: {torch.version.cuda}")

# Check GPU
print(f"GPU: {torch.cuda.get_device_name(0)}")

# Quick test
x = torch.randn(1000, 1000).cuda()
print(f"GPU test: {x.device}")
```