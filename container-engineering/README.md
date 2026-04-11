# Container Engineering for ML

This skill provides comprehensive guidance and tooling for building optimized Docker containers for machine learning training on GPUs.

## What's Inside

| Directory | Contents |
|-----------|----------|
| `SKILL.md` | Full documentation with workflows and examples |
| `scripts/` | Executable scripts for building, testing, and validating containers |
| `references/` | Quick reference docs, compatibility matrices, cheatsheets |

## Quick Start

### 1. Choose a Dockerfile Template

- **`Dockerfile.template.uv`** (Recommended) - Modern, fast builds with uv
- **`Dockerfile.template.pip`** - Traditional pip-based builds
- **`Dockerfile.template.vertex`** - Optimized for Google Cloud Vertex AI

### 2. Validate Your Environment

```bash
cd scripts
./validate-cuda.sh 12.4  # Check if your host supports CUDA 12.4
```

### 3. Build and Test Locally

```bash
# Build with uv template
cp Dockerfile.template.uv Dockerfile
# Edit Dockerfile for your needs, then:

export PROJECT_ID=your-project
export REGION=us-central1

./build-and-push.sh v1.0.0
./test-container-locally.sh v1.0.0
```

### 4. Deploy to Cloud

Use the container URI in your Vertex AI, SageMaker, or RunPod jobs.

## Key Features

- **Multi-stage builds**: 8GB → ~1.5GB image size reduction
- **uv integration**: 10-100x faster Python package installation
- **CUDA compatibility**: Validated matrices for driver/runtime matching
- **Layer caching**: Optimized for CI/CD with BuildKit
- **GPU testing**: Automated local validation before cloud deployment
- **Multi-platform**: Linux/AMD64 builds for cloud deployment

## File Reference

### Scripts

| Script | Purpose |
|--------|---------|
| `build-and-push.sh` | Build with layer caching and push to Artifact Registry |
| `test-container-locally.sh` | Comprehensive GPU/CUDA validation |
| `validate-cuda.sh` | Check host/container CUDA compatibility |

### Templates

| Template | Best For |
|----------|----------|
| `Dockerfile.template.uv` | New projects, fastest builds |
| `Dockerfile.template.pip` | Maximum compatibility |
| `Dockerfile.template.vertex` | Google Cloud Vertex AI |

### References

| File | Contents |
|------|----------|
| `cuda-compatibility-matrix.md` | CUDA/driver/GPU version matrix |
| `cheatsheet.md` | Quick command reference |

## Next Steps

After completing this skill:
1. **Skill 3**: Cloud Storage & Artifact Management - Set up GCS buckets for training data
2. **Skill 5**: Cloud Job Orchestration - Run your container on Vertex AI

## External Links

- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/)
- [uv Documentation](https://docs.astral.sh/uv/)
- [PyTorch Docker Guide](https://pytorch.org/docs/stable/docker.html)
- [Google Cloud Build](https://cloud.google.com/build/docs)