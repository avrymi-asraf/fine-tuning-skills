# Cloud Job Orchestration Skill

A comprehensive guide and toolkit for orchestrating ML training jobs on cloud platforms including Vertex AI (GCP), SageMaker (AWS), and RunPod.

## What's Included

### 📚 SKILL.md
The main skill documentation covering:
- Platform comparison (Vertex AI vs SageMaker vs RunPod)
- GPU machine type selection guide
- Job submission methods (SDK, CLI, config files)
- Spot VM strategies and preemption handling
- Job monitoring and logging
- Cost estimation and budgeting
- Common pitfalls and solutions

### 🔧 Scripts (`scripts/`)

| Script | Purpose |
|--------|---------|
| `submit-training-job.py` | Submit jobs to Vertex AI with full configuration options |
| `cost-estimate.py` | Calculate training costs across platforms (Vertex, SageMaker, RunPod) |
| `monitor-job.sh` | Stream logs and monitor job status in real-time |
| `cancel-job.sh` | Cancel/stop a running job |
| `handle-preemption.sh` | Automatically restart preempted Spot VM jobs |
| `example-job-config.yaml` | Sample configuration file |

### 📖 References (`references/`)

| File | Contents |
|------|----------|
| `documentation-links.md` | Official documentation URLs for all platforms |
| `gpu-machine-types.md` | Complete GPU/machine type comparison tables |
| `command-cheat-sheet.md` | Quick reference for common commands |

## Quick Start

### 1. Estimate Costs Before Training

```bash
python scripts/cost-estimate.py --machine-type a2-highgpu-1g --hours 24 --use-spot
```

### 2. Submit a Training Job

```bash
python scripts/submit-training-job.py \
  --machine-type a2-highgpu-1g \
  --container-uri gcr.io/PROJECT/training:v1 \
  --use-spot \
  --save-job-id .last_job_id
```

### 3. Monitor the Job

```bash
./scripts/monitor-job.sh $(cat .last_job_id)
```

### 4. Handle Preemption (Automatic Retry)

```bash
./scripts/handle-preemption.sh --config configs/training.yaml --max-retries 5
```

## Key Concepts

### Spot VMs vs On-Demand
- **Spot VMs**: 60-91% discount, but can be preempted anytime
- **On-Demand**: Full price, guaranteed capacity
- **Best Practice**: Use Spot for fault-tolerant training with checkpointing

### GPU Selection
- **H100**: Latest generation, best for large models (>40B parameters)
- **A100**: Proven workhorse, widely available
- **L4**: Cost-effective for inference and smaller training jobs
- **T4**: Budget option for experimentation

### Platform Selection
- **Vertex AI**: Best for GCP-native workflows, integrated MLOps
- **SageMaker**: Best for AWS-native workflows, extensive features
- **RunPod**: Best for cost-sensitive, quick experiments

## Prerequisites

- Python 3.9+
- gcloud CLI (for Vertex AI)
- AWS CLI (for SageMaker)
- Docker (for container builds)

## Installation

```bash
# Install dependencies for scripts
pip install google-cloud-aiplatform pyyaml click tabulate

# Or run with uv (dependencies auto-installed via PEP 723)
uv run scripts/submit-training-job.py --help
```

## Related Skills

This is Skill 5 of 6 in the fine-tuning suite:
1. Cloud Infrastructure Setup
2. Container Engineering for ML
3. Cloud Storage & Artifact Management
4. ML Training Pipeline
5. **Cloud Job Orchestration** (this skill)
6. Model Distribution & Deployment

## License

Part of the OpenClaw fine-tuning skills collection.
