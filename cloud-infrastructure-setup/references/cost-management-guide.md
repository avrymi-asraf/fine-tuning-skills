# Cost Management Guide for GCP ML Training

Strategies and best practices for managing costs in GCP ML training workloads.

## Cost Drivers in ML Training

### Primary Cost Factors

1. **Compute (GPUs/TPUs)** - 70-90% of training costs
2. **Storage (GCS)** - Model artifacts, checkpoints, datasets
3. **Networking** - Data transfer, especially egress
4. **Additional Services** - Logging, monitoring, build time

### GPU Pricing Comparison (us-central1, per hour)

| GPU Type | On-Demand | Spot VM | Savings |
|----------|-----------|---------|---------|
| NVIDIA T4 | ~$0.35 | ~$0.10 | 71% |
| NVIDIA V100 | ~$2.48 | ~$0.74 | 70% |
| NVIDIA A100 | ~$2.93 | ~$0.88 | 70% |
| NVIDIA L4 | ~$0.77 | ~$0.23 | 70% |
| NVIDIA H100 | ~$8.00+ | ~$2.40 | 70% |

*Prices subject to change - check [GCP pricing](https://cloud.google.com/compute/gpus-pricing)*

---

## Spot VMs (Preemptible Instances)

### When to Use Spot VMs

**✅ Good for:**
- Development and experimentation
- Fault-tolerant training with checkpointing
- Batch processing jobs
- Distributed training with redundancy
- Hyperparameter tuning

**❌ Avoid for:**
- Time-critical production jobs
- Jobs without checkpointing
- Single-node long-running training
- Interactive development

### Implementation

#### With gcloud CLI (YAML config)

Spot scheduling must be set via YAML config file, not CLI flags:

```yaml
# job-config.yaml
workerPoolSpecs:
  - machineSpec:
      machineType: n1-standard-4
      acceleratorType: NVIDIA_TESLA_T4
      acceleratorCount: 1
    replicaCount: 1
    containerSpec:
      imageUri: us-docker.pkg.dev/vertex-ai/training/tf-gpu.2-12:latest
scheduling:
  strategy: SPOT
  timeout: 86400s
```

```bash
gcloud ai custom-jobs create \
  --region=us-central1 \
  --display-name=spot-training \
  --config=job-config.yaml
```

> **Note:** The `--scheduling-strategy` CLI flag does not exist in current gcloud versions. Always use YAML config or the Python SDK for Spot scheduling.

#### With Vertex AI SDK

```python
from google.cloud import aiplatform

job = aiplatform.CustomJob(
    display_name="spot-training",
    worker_pool_specs=[{
        "machine_spec": {
            "machine_type": "n1-standard-4",
            "accelerator_type": "NVIDIA_TESLA_T4",
            "accelerator_count": 1,
        },
        "replica_count": 1,
        "container_spec": {
            "image_uri": "us-docker.pkg.dev/vertex-ai/training/tf-gpu.2-12:latest",
        },
    }],
    scheduling={"strategy": "SPOT", "max_wait_duration": "3600s"},
)

job.run(sync=False)
```

#### With REST API

```json
{
  "displayName": "spot-training",
  "jobSpec": {
    "workerPoolSpecs": [...],
    "scheduling": {
      "strategy": "SPOT"
    }
  }
}
```

### Checkpointing Strategy

Essential for Spot VM workloads:

```python
import os
from google.cloud import storage

def get_checkpoint_path(bucket_name, job_name):
    """Generate checkpoint path in GCS."""
    return f"gs://{bucket_name}/checkpoints/{job_name}"

def save_checkpoint(model, optimizer, epoch, loss, checkpoint_dir):
    """Save training checkpoint to GCS."""
    import torch
    
    checkpoint = {
        'epoch': epoch,
        'model_state_dict': model.state_dict(),
        'optimizer_state_dict': optimizer.state_dict(),
        'loss': loss,
    }
    
    # Save locally first
    local_path = f"/tmp/checkpoint_{epoch}.pt"
    torch.save(checkpoint, local_path)
    
    # Upload to GCS
    checkpoint_uri = f"{checkpoint_dir}/checkpoint_{epoch}.pt"
    os.system(f"gsutil cp {local_path} {checkpoint_uri}")
    
    return checkpoint_uri

def load_latest_checkpoint(model, optimizer, checkpoint_dir):
    """Load the most recent checkpoint."""
    import torch
    
    # List checkpoints
    result = os.popen(f"gsutil ls {checkpoint_dir}/checkpoint_*.pt 2>/dev/null || echo ''").read()
    checkpoints = result.strip().split('\n') if result.strip() else []
    
    if not checkpoints or checkpoints == ['']:
        return model, optimizer, 0, float('inf')
    
    # Get latest checkpoint
    latest = sorted(checkpoints)[-1]
    local_path = "/tmp/checkpoint_latest.pt"
    os.system(f"gsutil cp {latest} {local_path}")
    
    checkpoint = torch.load(local_path)
    model.load_state_dict(checkpoint['model_state_dict'])
    optimizer.load_state_dict(checkpoint['optimizer_state_dict'])
    
    return model, optimizer, checkpoint['epoch'], checkpoint['loss']

# Training loop with checkpointing
checkpoint_dir = get_checkpoint_path(os.environ['GCS_BUCKET'], os.environ['JOB_NAME'])
model, optimizer, start_epoch, best_loss = load_latest_checkpoint(model, optimizer, checkpoint_dir)

for epoch in range(start_epoch, total_epochs):
    # Training code...
    
    # Save checkpoint every N epochs
    if epoch % 5 == 0:
        save_checkpoint(model, optimizer, epoch, loss, checkpoint_dir)
```

### Handling Preemption

Vertex AI automatically retries Spot VM jobs up to 6 times:

```python
# In your training script, check for preemption signal
import os
import sys
import signal

def handle_preemption(signum, frame):
    print("Received preemption signal. Saving checkpoint...")
    save_checkpoint(model, optimizer, epoch, loss, checkpoint_dir)
    sys.exit(0)

# Register signal handler
signal.signal(signal.SIGTERM, handle_preemption)

# Also check for shutdown script
def check_metadata_for_preemption():
    """Check instance metadata for preemption notice."""
    import requests
    try:
        response = requests.get(
            "http://metadata.google.internal/computeMetadata/v1/instance/preempted",
            headers={"Metadata-Flavor": "Google"},
            timeout=2
        )
        return response.text == "TRUE"
    except:
        return False

# Periodically check in training loop
if check_metadata_for_preemption():
    handle_preemption(None, None)
```

---

## Budget Alerts

### Setting Up Budgets

#### With gcloud CLI

```bash
# Create budget with email alerts
gcloud billing budgets create \
  --billing-account=XXXXXX-XXXXXX-XXXXXX \
  --display-name="ML Training Budget" \
  --budget-amount=5000USD \
  --threshold-rule=percent=50 \
  --threshold-rule=percent=80 \
  --threshold-rule=percent=100

# With Pub/Sub for programmatic handling
gcloud billing budgets create \
  --billing-account=XXXXXX-XXXXXX-XXXXXX \
  --display-name="ML Training Budget - PubSub" \
  --budget-amount=5000USD \
  --threshold-rule=percent=80 \
  --pubsub-topic=projects/my-project/topics/budget-alerts
```

#### With Cloud Console

1. Go to Billing → Budgets & alerts
2. Click "Create budget"
3. Set scope (entire billing account or specific projects)
4. Set amount (specify or last month's spend)
5. Configure alerts (recommended: 50%, 80%, 100%)
6. Optional: Connect Pub/Sub topic for automation

### Automated Cost Control

Respond to budget alerts programmatically:

```python
import base64
import json
from google.cloud import aiplatform

def handle_budget_alert(event, context):
    """Cloud Function to handle budget alerts."""
    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    alert = json.loads(pubsub_message)
    
    alert_threshold = alert['alertThresholdExceeded']
    cost_amount = float(alert['costAmount'])
    budget_amount = float(alert['budgetAmount'])
    
    print(f"Budget alert: {alert_threshold}% exceeded")
    print(f"Cost: ${cost_amount}, Budget: ${budget_amount}")
    
    # Take action based on threshold
    if alert_threshold >= 1.0:  # 100%
        # Cancel non-essential jobs
        cancel_non_production_jobs()
    elif alert_threshold >= 0.8:  # 80%
        # Switch new jobs to Spot VMs
        enable_force_spot_vms()
        send_alert_notification("Approaching budget limit")

def cancel_non_production_jobs():
    """Cancel jobs not marked as production."""
    aiplatform.init(project='my-project', location='us-central1')
    
    jobs = aiplatform.CustomJob.list()
    for job in jobs:
        labels = job.gca_resource.labels or {}
        if labels.get('environment') != 'production':
            print(f"Cancelling job: {job.display_name}")
            job.cancel()
```

---

## Quota Management

### Understanding Quotas

Quotas limit resource usage to prevent unexpected costs:

| Quota Type | Default | Typical Limit |
|------------|---------|---------------|
| CPUs per region | 24 | 96+ |
| GPUs per region (T4) | 1 | 8+ |
| GPUs per region (A100) | 0 | 1-8 |
| In-use IP addresses | 8 | 32+ |
| Persistent Disk (GB) | 5000 | 20000+ |

### Checking Quotas

```bash
# View regional quotas
gcloud compute regions describe us-central1 --format="table(quotas.metric:label=Metric, quotas.limit:label=Limit, quotas.usage:label=Usage)"

# Filter for GPU quotas
gcloud compute regions describe us-central1 --format="table(quotas.metric, quotas.limit, quotas.usage)" | grep GPU

# View all quotas with filter
gcloud compute project-info describe --format="json" | jq '.quotas[] | select(.metric | contains("gpu"))'
```

### Requesting Quota Increases

```bash
# View current limits and request increases in Cloud Console:
# IAM & Admin → Quotas → Select metric → Edit Quotas

# Or use gcloud to view (request must be done via Console)
gcloud compute regions describe us-central1 --format="json" | jq '.quotas[] | {metric: .metric, limit: .limit, usage: .usage}'
```

Best practices:
- Request increases 2-3 business days in advance
- Provide business justification
- Start with conservative increases
- Monitor usage before requesting more

---

## Cost Optimization Strategies

### 1. Right-Sizing Resources

Choose appropriate machine types:

```bash
# Development: Small CPU-only
--machine-type=n1-standard-4
--accelerator-count=0

# Small GPU training
--machine-type=n1-standard-4
--accelerator-type=NVIDIA_TESLA_T4
--accelerator-count=1

# Large-scale training
--machine-type=a2-highgpu-1g  # A100 optimized
--accelerator-type=NVIDIA_TESLA_A100
--accelerator-count=1
```

### 2. Automatic Shutdown

```python
# Set max runtime to prevent runaway jobs
job.run(
    scheduling_strategy="SPOT",
    timeout=3600 * 4,  # 4 hours max
    restart_job_on_worker_restart=False,
)
```

### 3. Label-Based Cost Tracking

```bash
# Apply labels to all resources
gcloud ai custom-jobs create \
  --labels=project=experiment-1,team=ml-research,environment=dev \
  ...
```

View costs by label in Cloud Billing Reports.

### 4. GCS Lifecycle Policies

```bash
# Automatically delete old checkpoints
cat > lifecycle.json << EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {
          "age": 30,
          "matchesPrefix": ["checkpoints/"]
        }
      }
    ]
  }
}
EOF

gsutil lifecycle set lifecycle.json gs://BUCKET_NAME
```

### 5. Use Committed Use Discounts (CUDs)

For predictable workloads:
- 1-year commitment: ~37% discount
- 3-year commitment: ~55% discount

Only purchase CUDs for baseline capacity, use Spot VMs for variable load.

---

## Cost Monitoring

### View Costs by Service

```bash
# Export billing data to BigQuery first
gcloud billing accounts export-bigquery \
  --billing-account=XXXXXX-XXXXXX-XXXXXX \
  --dataset-id=my-project:my-dataset

# Query costs by service
SELECT
  service.description,
  SUM(cost) as total_cost
FROM `my-project.my-dataset.gcp_billing_export_v1_XXXXXX`
WHERE DATE(usage_start_time) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY service.description
ORDER BY total_cost DESC
```

### Cost Estimation Before Training

```python
from google.cloud import aiplatform

# Estimate job cost
machine_type = "n1-standard-4"
gpu_type = "NVIDIA_TESLA_T4"
gpu_count = 1
hours = 4

# Rough pricing (check current prices)
machine_cost = 0.19  # n1-standard-4 per hour
gpu_cost = 0.35      # T4 per hour (on-demand)

estimated_cost = (machine_cost + (gpu_cost * gpu_count)) * hours
print(f"Estimated cost: ${estimated_cost:.2f}")

# With Spot VM
spot_cost = estimated_cost * 0.30  # 70% savings
print(f"Estimated cost with Spot VM: ${spot_cost:.2f}")
```

---

## Quick Reference: Cost Commands

```bash
# View current billing info
gcloud billing accounts list
gcloud billing accounts describe XXXXXX-XXXXXX-XXXXXX

# List budgets
gcloud billing budgets list --billing-account=XXXXXX-XXXXXX-XXXXXX

# View detailed costs (requires BigQuery export setup)
bq query --use_legacy_sql=false 'SELECT SUM(cost) FROM `project.dataset.gcp_billing_export` WHERE DATE(usage_start_time) = CURRENT_DATE()'

# Check if billing is enabled for project
gcloud beta billing projects describe PROJECT_ID
```
