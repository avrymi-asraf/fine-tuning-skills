# Cloud Job Orchestration

Orchestrate ML training jobs on cloud platforms (Vertex AI, SageMaker, RunPod, etc.). Manage GPU selection, spot instances, monitoring, cost estimation, and job lifecycle.

---

## Purpose

This skill covers:

- **Job Submission**: Creating and launching training jobs on cloud ML platforms
- **GPU/Machine Selection**: Choosing optimal machine types and GPU configurations
- **Cost Optimization**: Spot/preemptible instances, reservations, and pricing strategies
- **Job Monitoring**: Logs, metrics, status tracking, and debugging
- **Preemption Handling**: Checkpointing and recovery for fault-tolerant training
- **Platform Comparison**: Vertex AI vs SageMaker vs Lambda vs RunPod

---

## Prerequisites

1. **Cloud CLI installed and authenticated**:
   ```bash
   # GCP/Vertex AI
   gcloud auth application-default login
   gcloud config set project YOUR_PROJECT_ID
   
   # AWS/SageMaker
   aws configure
   
   # RunPod (API key)
   export RUNPOD_API_KEY=your_key
   ```

2. **Container image pushed to registry**:
   ```bash
   # GCP Artifact Registry or GCR
   gcr.io/PROJECT_ID/training-image:tag
   
   # AWS ECR
   ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/training-image:tag
   ```

3. **Cloud Storage buckets configured**:
   ```bash
   # GCP GCS
   gs://your-bucket/datasets/
   gs://your-bucket/outputs/
   
   # AWS S3
   s3://your-bucket/datasets/
   ```

4. **Python dependencies**:
   ```bash
   pip install google-cloud-aiplatform boto3 sagemaker runpod
   ```

---

## Quick Reference: Platform Comparison

| Feature | Vertex AI | SageMaker | RunPod | Lambda Labs |
|---------|-----------|-----------|--------|-------------|
| **GPU Types** | H100, A100, L4, T4, V100, TPU | H100, A100, V100, T4 | H100, A100, RTX 4090/3090 | H100, A100, RTX A6000 |
| **Spot/Preemptible** | Yes (60-91% discount) | Yes (Spot Training) | Yes | Limited |
| **On-Demand Pricing** | Higher | Higher | Lower | Lower |
| **Cold Start** | 2-5 min | 2-5 min | 10-30 sec | 2-5 min |
| **Autoscaling** | Yes | Yes | No | No |
| **Reserved Capacity** | Yes (CUDs) | Yes (Savings Plans) | No | Yes |
| **MLOps Integration** | Native (Pipelines, Experiments) | Native (Pipelines, Model Registry) | Minimal | Minimal |
| **Best For** | Enterprise, GCP shops | Enterprise, AWS shops | Quick experiments, cost-sensitive | Cost-sensitive, simple workloads |

---

## GPU Machine Type Selection Guide

### Vertex AI Machine Types

#### A3 Series (H100 GPUs - Latest Generation)
| Machine Type | GPUs | GPU Memory | vCPUs | RAM | Use Case |
|--------------|------|------------|-------|-----|----------|
| `a3-highgpu-1g` | 1x H100 | 80 GB | 12 | 170 GB | Single-GPU LLM fine-tuning |
| `a3-highgpu-2g` | 2x H100 | 160 GB | 24 | 340 GB | Medium-scale distributed training |
| `a3-highgpu-4g` | 4x H100 | 320 GB | 48 | 680 GB | Large-scale training |
| `a3-highgpu-8g` | 8x H100 | 640 GB | 96 | 1360 GB | Full-node distributed training |
| `a3-megagpu-8g` | 8x H100 Mega | 640 GB | 96 | 1360 GB | Multi-node with GPUDirect-TCPXO |
| `a3-ultragpu-8g` | 8x H200 | 1128 GB | 208 | 2048 GB | Largest models, GPUDirect-RDMA |

#### A2 Series (A100 GPUs)
| Machine Type | GPUs | GPU Memory | vCPUs | RAM | Use Case |
|--------------|------|------------|-------|-----|----------|
| `a2-highgpu-1g` | 1x A100 40GB | 40 GB | 12 | 170 GB | Standard training/inference |
| `a2-highgpu-2g` | 2x A100 40GB | 80 GB | 24 | 340 GB | Multi-GPU training |
| `a2-highgpu-4g` | 4x A100 40GB | 160 GB | 48 | 680 GB | Distributed training |
| `a2-highgpu-8g` | 8x A100 40GB | 320 GB | 96 | 1360 GB | Large-scale distributed |
| `a2-ultragpu-1g` | 1x A100 80GB | 80 GB | 12 | 170 GB | Large model training |
| `a2-ultragpu-8g` | 8x A100 80GB | 640 GB | 96 | 1360 GB | Maximum A100 capacity |
| `a2-megagpu-16g` | 16x A100 40GB | 640 GB | 96 | 1360 GB | Maximum GPU density |

#### G2 Series (L4 GPUs - Cost-Effective Inference)
| Machine Type | GPUs | GPU Memory | vCPUs | RAM | Use Case |
|--------------|------|------------|-------|-----|----------|
| `g2-standard-4` | 1x L4 | 24 GB | 4 | 16 GB | Inference, small training |
| `g2-standard-8` | 1x L4 | 24 GB | 8 | 32 GB | Light training workloads |
| `g2-standard-24` | 2x L4 | 48 GB | 24 | 96 GB | Medium training |
| `g2-standard-48` | 4x L4 | 96 GB | 48 | 192 GB | Multi-GPU training |

#### N1 Series with GPUs (Legacy/Cost-Effective)
| Machine Type | Compatible GPUs | Max GPUs | Use Case |
|--------------|-----------------|----------|----------|
| `n1-standard-4` | T4, P4, V100, P100 | 1-4 | Small experiments |
| `n1-standard-8` | T4, P4, V100, P100 | 1-4 | Development |
| `n1-standard-16` | T4, P4, V100, P100 | 2-4 | Medium workloads |
| `n1-standard-32` | T4, P4, V100, P100 | 2-4 | Production training |
| `n1-highmem-*` | T4, P4, V100, P100 | 1-4 | Memory-intensive |

### GPU Selection Decision Tree

```
Starting New Project?
├── Yes → Use a3-highgpu-1g (H100) for single GPU
│         or a2-highgpu-1g (A100) for cost savings
│
├── Large model (>40B parameters)?
│   ├── Yes → a3-highgpu-8g or a3-ultragpu-8g
│   └── No → Continue...
│
├── Multi-GPU distributed?
│   ├── Yes → a3-highgpu-2g/4g/8g or a2-highgpu-*
│   └── No → Continue...
│
├── Inference only?
│   ├── Yes → g2-standard-* (L4) or n1 with T4
│   └── No → Continue...
│
├── Budget constrained?
│   ├── Yes → Spot VMs on n1-standard-16 + V100/T4
│   └── No → a3/a2 on-demand
│
└── Need TPU?
    ├── Yes → ct5lp-hightpu-1t/4t/8t or ct6e-*
    └── No → Use GPU options above
```

---

## Vertex AI Job Submission

### Method 1: CustomContainerTrainingJob (SDK)

```python
from google.cloud import aiplatform

# Initialize
aiplatform.init(project="PROJECT_ID", location="us-central1")

# Create job
job = aiplatform.CustomContainerTrainingJob(
    display_name="llm-finetuning-job",
    container_uri="gcr.io/PROJECT_ID/training-image:v1",
    model_serving_container_image_uri=None,  # Skip model upload
)

# Run with GPU
job.run(
    machine_type="a2-highgpu-1g",
    accelerator_type="NVIDIA_TESLA_A100",
    accelerator_count=1,
    replica_count=1,
    base_output_dir="gs://your-bucket/outputs/job-001",
    environment_variables={
        "MODEL_NAME": "meta-llama/Llama-2-7b",
        "BATCH_SIZE": "4",
        "EPOCHS": "3",
    },
    sync=False,  # Don't wait for completion
)
```

### Method 2: CustomJob (Lower Level)

```python
from google.cloud import aiplatform

job = aiplatform.CustomJob(
    display_name="training-job",
    worker_pool_specs=[
        {
            "machine_spec": {
                "machine_type": "a3-highgpu-1g",
                "accelerator_type": "NVIDIA_H100_80GB",
                "accelerator_count": 1,
            },
            "replica_count": 1,
            "container_spec": {
                "image_uri": "gcr.io/PROJECT/training:v1",
                "command": ["python", "train.py"],
                "args": ["--config", "config.yaml"],
                "env": [
                    {"name": "MODEL_NAME", "value": "llama-2-7b"},
                ],
            },
            "disk_spec": {
                "boot_disk_type": "pd-ssd",
                "boot_disk_size_gb": 500,
            },
        }
    ],
    base_output_dir="gs://bucket/outputs",
)

job.run(sync=False)
print(f"Job submitted: {job.resource_name}")
```

### Method 3: gcloud CLI with Config File

Create `job_config.yaml`:

```yaml
workerPoolSpecs:
  - machineSpec:
      machineType: a2-highgpu-1g
      acceleratorType: NVIDIA_TESLA_A100
      acceleratorCount: 1
    replicaCount: 1
    containerSpec:
      imageUri: gcr.io/PROJECT/training:v1
      command:
        - python
        - train.py
      env:
        - name: MODEL_NAME
          value: llama-2-7b
        - name: OUTPUT_DIR
          value: $(AIP_MODEL_DIR)
    diskSpec:
      bootDiskType: pd-ssd
      bootDiskSizeGb: 500

baseOutputDirectory:
  outputUriPrefix: gs://your-bucket/outputs/job-001

scheduling:
  timeout: 86400s  # 24 hours
```

Submit:
```bash
gcloud ai custom-jobs create \
  --region=us-central1 \
  --display-name=training-job \
  --config=job_config.yaml
```

---

## Spot VMs & Preemption Handling

### What are Spot VMs?

- **Discount**: 60-91% off on-demand pricing
- **Risk**: Can be preempted (stopped/deleted) at any time
- **Best for**: Fault-tolerant, checkpoint-aware training

### Enabling Spot VMs

```python
from google.cloud import aiplatform

job = aiplatform.CustomJob(
    display_name="spot-training-job",
    worker_pool_specs=[...],
    scheduling={
        "strategy": "SPOT",  # Enable spot
        "max_wait_duration": "3600s",  # Wait up to 1 hour for capacity
    },
)
```

Or in config file:
```yaml
scheduling:
  strategy: SPOT
  maxWaitDuration: 3600s
```

### Handling Preemption in Training Code

```python
import os
import signal
import sys
import torch
from transformers import TrainerCallback

class PreemptionCallback(TrainerCallback):
    """Handle GCP preemption gracefully."""
    
    def __init__(self, checkpoint_dir):
        self.checkpoint_dir = checkpoint_dir
        self.preempted = False
        
        # Set up signal handler
        signal.signal(signal.SIGTERM, self._handle_sigterm)
    
    def _handle_sigterm(self, signum, frame):
        """SIGTERM is sent 30s before preemption."""
        print("⚠️  Preemption warning received! Saving checkpoint...")
        self.preempted = True
        # Trigger checkpoint save
        if hasattr(self, 'control'):
            self.control.should_save = True
    
    def on_step_end(self, args, state, control, **kwargs):
        if self.preempted:
            control.should_training_stop = True
        return control

# In training script
trainer = Trainer(
    ...,
    callbacks=[PreemptionCallback(os.environ.get("AIP_CHECKPOINT_DIR", "/gcs/checkpoints"))],
)
```

### Checkpointing Strategy

```python
import os
from transformers import TrainingArguments

# Vertex AI sets these environment variables automatically
output_dir = os.environ.get("AIP_MODEL_DIR", "/gcs/output")
checkpoint_dir = os.environ.get("AIP_CHECKPOINT_DIR", "/gcs/checkpoints")

# Resume from checkpoint if exists
last_checkpoint = None
if os.path.isdir(checkpoint_dir) and len(os.listdir(checkpoint_dir)) > 0:
    last_checkpoint = get_last_checkpoint(checkpoint_dir)
    print(f"Resuming from checkpoint: {last_checkpoint}")

training_args = TrainingArguments(
    output_dir=output_dir,
    save_strategy="steps",
    save_steps=100,
    save_total_limit=3,
    resume_from_checkpoint=last_checkpoint,
    # For spot instances, save more frequently
    save_safetensors=True,
)
```

### Preemption Recovery Script

```bash
#!/bin/bash
# handle-preemption.sh

JOB_NAME="${1:-training-job}"
REGION="${2:-us-central1}"
MAX_RETRIES=5
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    echo "Starting job attempt $((RETRY_COUNT + 1))..."
    
    # Submit job
    JOB_ID=$(gcloud ai custom-jobs create \
        --region=$REGION \
        --display-name="${JOB_NAME}-retry-${RETRY_COUNT}" \
        --config=spot_job_config.yaml \
        --format='value(name)')
    
    # Monitor
    while true; do
        STATUS=$(gcloud ai custom-jobs describe $JOB_ID \
            --region=$REGION \
            --format='value(state)')
        
        echo "Job status: $STATUS"
        
        case $STATUS in
            "JOB_STATE_SUCCEEDED")
                echo "Job completed successfully!"
                exit 0
                ;;
            "JOB_STATE_FAILED"|"JOB_STATE_CANCELLED")
                echo "Job failed or was cancelled."
                exit 1
                ;;
            "JOB_STATE_PREEMPTING"|"JOB_STATE_PREEMPTED")
                echo "Job was preempted. Retrying..."
                RETRY_COUNT=$((RETRY_COUNT + 1))
                sleep 30
                break
                ;;
        esac
        
        sleep 60
    done
done

echo "Max retries reached. Job failed."
exit 1
```

---

## Job Monitoring

### Real-Time Log Streaming

```bash
# Get job ID
JOB_ID=$(gcloud ai custom-jobs list --region=us-central1 \
  --filter="displayName:training-job" --format="value(name)" | head -1)

# Stream logs
gcloud ai custom-jobs stream-logs $JOB_ID --region=us-central1
```

### Python SDK Monitoring

```python
from google.cloud import aiplatform

job = aiplatform.CustomJob.get("projects/PROJECT/locations/REGION/customJobs/JOB_ID")

# Get status
print(f"State: {job.state}")
print(f"Start time: {job.start_time}")
print(f"End time: {job.end_time}")

# Wait for completion
job.wait_for_resource_creation()
job.wait()  # Blocks until completion
```

### Cloud Monitoring Metrics

```python
from google.cloud import monitoring_v3

client = monitoring_v3.MetricServiceClient()
project_name = f"projects/{PROJECT_ID}"

# List available metrics for your job
filter_str = '''
    resource.type="aiplatform.googleapis.com/CustomJob"
    resource.labels.job_id="JOB_ID"
'''

results = client.list_time_series(
    request={
        "name": project_name,
        "filter": filter_str,
        "interval": monitoring_v3.TimeInterval({
            "end_time": {"seconds": int(time.time())},
            "start_time": {"seconds": int(time.time()) - 3600},
        }),
    }
)

for result in results:
    print(f"Metric: {result.metric.type}")
    print(f"Points: {list(result.points)}")
```

### TensorBoard Integration

```python
from google.cloud import aiplatform

# Create TensorBoard
tensorboard = aiplatform.TensorBoard.create(display_name="training-logs")

# Run job with TensorBoard
job = aiplatform.CustomContainerTrainingJob(
    display_name="training-with-tb",
    container_uri="gcr.io/PROJECT/training:v1",
    tensorboard=tensorboard.resource_name,
)

job.run(
    machine_type="a2-highgpu-1g",
    accelerator_type="NVIDIA_TESLA_A100",
    accelerator_count=1,
)
```

---

## Cost Estimation

### GCP Pricing (Approximate, subject to change)

| GPU Type | On-Demand/hr | Spot/hr | 1-Year CUD | 3-Year CUD |
|----------|-------------|---------|------------|------------|
| H100 80GB | ~$4.50 | ~$1.35 | ~$2.84 | ~$2.03 |
| A100 40GB | ~$2.48 | ~$0.74 | ~$1.56 | ~$1.12 |
| A100 80GB | ~$3.67 | ~$1.10 | ~$2.31 | ~$1.65 |
| L4 | ~$0.80 | ~$0.24 | ~$0.50 | ~$0.36 |
| T4 | ~$0.35 | ~$0.11 | ~$0.22 | ~$0.16 |
| V100 | ~$2.48 | ~$0.74 | ~$1.56 | ~$1.12 |

*Plus machine type costs and boot disk charges*

### Cost Estimation Script

See `scripts/cost-estimate.py` for a complete cost calculator.

Basic usage:
```bash
python scripts/cost-estimate.py \
  --machine-type a2-highgpu-1g \
  --hours 24 \
  --use-spot
```

### Budget Alerts

```python
from google.cloud import billing_budgets_v1

client = billing_budgets_v1.BudgetServiceClient()

budget = billing_budgets_v1.Budget(
    display_name="ML Training Budget",
    budget_filter=billing_budgets_v1.Filter(
        projects=[f"projects/{PROJECT_ID}"],
        credit_types_treatment=billing_budgets_v1.Filter.CreditTypesTreatment.INCLUDE_ALL_CREDITS,
    ),
    amount=billing_budgets_v1.BudgetAmount(
        specified_amount=currency_pb2.Money(currency_code="USD", units=1000)
    ),
    threshold_rules=[
        billing_budgets_v1.ThresholdRule(threshold_percent=50),
        billing_budgets_v1.ThresholdRule(threshold_percent=80),
        billing_budgets_v1.ThresholdRule(threshold_percent=100),
    ],
    all_updates_rule=billing_budgets_v1.AllUpdatesRule(
        pubsub_topic=f"projects/{PROJECT_ID}/topics/budget-alerts"
    ),
)

client.create_budget(
    billing_account=f"billingAccounts/{BILLING_ACCOUNT_ID}",
    budget=budget,
)
```

---

## Environment Variables & Secrets

### Standard Vertex AI Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `AIP_MODEL_DIR` | Output directory for model artifacts | `gs://bucket/outputs/model` |
| `AIP_TENSORBOARD_LOG_DIR` | TensorBoard log directory | `gs://bucket/logs` |
| `AIP_CHECKPOINT_DIR` | Checkpoint directory | `gs://bucket/checkpoints` |
| `AIP_DATA_FORMAT` | Data format for managed datasets | `jsonl` |
| `CLOUD_ML_JOB_ID` | Current job ID | `1234567890` |
| `CLOUD_ML_PROJECT_ID` | Project ID | `my-project-123` |

### Using Secret Manager

```python
from google.cloud import secretmanager

def get_secret(secret_id, project_id):
    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{project_id}/secrets/{secret_id}/versions/latest"
    response = client.access_secret_version(request={"name": name})
    return response.payload.data.decode("UTF-8")

# In training script
hf_token = get_secret("huggingface-token", os.environ["CLOUD_ML_PROJECT_ID"])
os.environ["HF_TOKEN"] = hf_token
```

### Passing Secrets via Environment

```yaml
workerPoolSpecs:
  - machineSpec: {...}
    containerSpec:
      imageUri: gcr.io/PROJECT/training:v1
      env:
        - name: HF_TOKEN_SECRET
          value: projects/PROJECT/secrets/hf-token/versions/latest
```

Then in code:
```python
import subprocess

def load_secret_from_env(env_var):
    """Load secret from Secret Manager reference in env var."""
    secret_path = os.environ.get(env_var)
    if secret_path and secret_path.startswith("projects/"):
        result = subprocess.run(
            ["gcloud", "secrets", "versions", "access", "latest", 
             "--secret", secret_path.split("/")[3]],
            capture_output=True, text=True
        )
        return result.stdout.strip()
    return secret_path
```

---

## AWS SageMaker Quick Reference

### Submit Training Job

```python
import sagemaker
from sagemaker.pytorch import PyTorch

estimator = PyTorch(
    entry_point="train.py",
    source_dir=".",
    role=sagemaker.get_execution_role(),
    framework_version="2.0.0",
    py_version="py310",
    instance_count=1,
    instance_type="ml.p4d.24xlarge",  # 8x A100
    use_spot_instances=True,  # Spot
    max_wait=86400,
    checkpoint_s3_uri="s3://bucket/checkpoints",
    checkpoint_local_path="/opt/ml/checkpoints",
    environment={
        "MODEL_NAME": "llama-2-7b",
    },
)

estimator.fit("s3://bucket/dataset/")
```

### Spot Instance Handling

```python
# SageMaker checkpointing is built-in
# Use checkpoint_s3_uri for automatic S3 sync

# In training code, checkpoints are at:
CHECKPOINT_DIR = "/opt/ml/checkpoints"

# Detect spot interruption
import json
import requests

def is_spot_interruption():
    try:
        response = requests.get(
            "http://169.254.169.254/latest/meta-data/spot/instance-action",
            timeout=2
        )
        return response.status_code == 200
    except:
        return False

# Check periodically during training
if is_spot_interruption():
    trainer.save_model(CHECKPOINT_DIR)
    trainer.save_state()
```

---

## RunPod Quick Reference

### Submit Job via API

```python
import runpod

runpod.api_key = os.environ["RUNPOD_API_KEY"]

pod = runpod.create_pod(
    name="training-job",
    image_name="gcr.io/PROJECT/training:v1",
    gpu_type_id="NVIDIA H100 80GB HBM3",
    cloud_type="COMMUNITY",  # or "SECURE" for datacenter
    container_disk_in_gb=50,
    volume_in_gb=500,
    ports="8888/http,22/tcp",
    env={
        "MODEL_NAME": "llama-2-7b",
        "PYTHONUNBUFFERED": "1",
    },
)

print(f"Pod created: {pod['id']}")
```

### Serverless GPU (Pay per second)

```python
import requests

# RunPod Serverless endpoint
endpoint_id = "your-endpoint-id"
api_key = os.environ["RUNPOD_API_KEY"]

response = requests.post(
    f"https://api.runpod.ai/v2/{endpoint_id}/run",
    headers={"Authorization": f"Bearer {api_key}"},
    json={
        "input": {
            "prompt": "Your training config here",
            "model": "llama-2-7b",
        }
    },
)
```

---

## Common Pitfalls & Solutions

### 1. GPU Out of Memory

**Problem**: `CUDA out of memory` error

**Solutions**:
```python
# Reduce batch size
training_args = TrainingArguments(
    per_device_train_batch_size=1,  # Start small
    gradient_accumulation_steps=8,  # Effective batch = 8
)

# Use gradient checkpointing
model.gradient_checkpointing_enable()

# Use DeepSpeed ZeRO
# See: https://huggingface.co/docs/transformers/main_classes/deepspeed
```

### 2. Job Stuck in "Queued"

**Problem**: Job stays queued for hours

**Solutions**:
- Use spot VMs (often better availability)
- Try different regions (us-central1, europe-west4)
- Use Dynamic Workload Scheduler for GPU-heavy jobs
- Request quota increase in advance

### 3. Preemption Loops

**Problem**: Job keeps getting preempted

**Solutions**:
- Use on-demand for critical jobs
- Increase checkpoint frequency
- Use reservations for guaranteed capacity
- Consider smaller machine types (better spot availability)

### 4. Container Startup Failures

**Problem**: Job fails immediately

**Solutions**:
```bash
# Test container locally first
docker run --gpus all gcr.io/PROJECT/training:v1 python -c "import torch; print(torch.cuda.is_available())"

# Check logs immediately
gcloud ai custom-jobs stream-logs JOB_ID
```

### 5. Slow Data Loading

**Problem**: GPU underutilized, CPU bottleneck

**Solutions**:
```python
# Increase dataloader workers
training_args = TrainingArguments(
    dataloader_num_workers=4,
    dataloader_pin_memory=True,
)

# Use TFRecord or WebDataset format
# Pre-load data to VM local SSD if possible
```

---

## Workflow: End-to-End Job Submission

```bash
# 1. Estimate cost
python scripts/cost-estimate.py --machine-type a2-highgpu-1g --hours 12

# 2. Build and push container
gcloud builds submit --tag gcr.io/PROJECT/training:v1 .

# 3. Submit job
python scripts/submit-training-job.py \
  --config configs/training_config.yaml \
  --use-spot

# 4. Monitor
python scripts/monitor-job.sh $(cat .last_job_id)

# 5. Download results
gsutil cp -r gs://bucket/outputs/job-001 ./results/
```

---

## See Also

- `scripts/` - Working scripts for job submission, monitoring, cost estimation
- `references/` - Documentation links, GPU comparison tables, cheat sheets
- Previous skills: Cloud Infrastructure Setup, Container Engineering, ML Training Pipeline
- Next skill: Model Distribution & Deployment
