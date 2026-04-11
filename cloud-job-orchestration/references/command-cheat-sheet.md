# Vertex AI Job Orchestration Cheat Sheet

## Job Management (gcloud)

```bash
# List all jobs in a region
gcloud ai custom-jobs list --region=us-central1

# Filter by name and state
gcloud ai custom-jobs list --region=us-central1 \
  --filter="displayName:training-job AND state=JOB_STATE_RUNNING"

# Get job details
gcloud ai custom-jobs describe JOB_ID --region=us-central1

# Stream logs (blocks until job ends)
gcloud ai custom-jobs stream-logs JOB_ID --region=us-central1

# Cancel a job
gcloud ai custom-jobs cancel JOB_ID --region=us-central1
```

## Submit Job (gcloud)

```bash
# Inline (simple — no config file)
gcloud ai custom-jobs create \
  --region=us-central1 \
  --display-name=my-job \
  --worker-pool-spec=machine-type=a2-highgpu-1g,replica-count=1,\
accelerator-type=NVIDIA_TESLA_A100,accelerator-count=1,\
container-image-uri=gcr.io/PROJECT/training:v1

# From config file (recommended for complex jobs)
gcloud ai custom-jobs create \
  --region=us-central1 \
  --display-name=my-job \
  --config=config.yaml
```

## Config File Format (gcloud)

```yaml
workerPoolSpecs:
  - machineSpec:
      machineType: a2-highgpu-1g
      acceleratorType: NVIDIA_TESLA_A100
      acceleratorCount: 1
    replicaCount: 1
    containerSpec:
      imageUri: gcr.io/PROJECT/training:v1
      command: [python, train.py]
      args: [--config, /gcs/config.yaml]
      env:
        - name: MODEL_NAME
          value: llama-2-7b
    diskSpec:
      bootDiskType: pd-ssd
      bootDiskSizeGb: 500
baseOutputDirectory:
  outputUriPrefix: gs://bucket/outputs/job-001
scheduling:
  strategy: SPOT
  timeout: 86400s
```

---

## Python SDK

### Initialize

```python
from google.cloud import aiplatform

aiplatform.init(
    project='my-project',
    location='us-central1',
    staging_bucket='gs://my-bucket/staging'
)
```

### Submit CustomJob

```python
# Method 1: CustomContainerTrainingJob (simpler)
job = aiplatform.CustomContainerTrainingJob(
    display_name='training-job',
    container_uri='gcr.io/PROJECT/training:v1',
)
job.run(
    machine_type='a2-highgpu-1g',
    accelerator_type='NVIDIA_TESLA_A100',
    accelerator_count=1,
    base_output_dir='gs://bucket/outputs',
    sync=False,
)

# Method 2: CustomJob (full control)
job = aiplatform.CustomJob(
    display_name='training-job',
    worker_pool_specs=[{
        'machine_spec': {
            'machine_type': 'a2-highgpu-1g',
            'accelerator_type': 'NVIDIA_TESLA_A100',
            'accelerator_count': 1,
        },
        'replica_count': 1,
        'container_spec': {
            'image_uri': 'gcr.io/PROJECT/training:v1',
            'command': ['python', 'train.py'],
        },
    }],
    base_output_dir='gs://bucket/outputs',
)
job.run(sync=False)
```

### Monitor Job

```python
# Get job by resource name
job = aiplatform.CustomJob.get('projects/PROJECT/locations/REGION/customJobs/JOB_ID')
print(f"State: {job.state}")

# Wait for completion (blocks)
job.wait()

# List jobs with filter
jobs = aiplatform.CustomJob.list(filter='display_name="training-job*"')
for j in jobs:
    print(f"{j.display_name}: {j.state}")
```

### Spot Scheduling

```python
job = aiplatform.CustomJob(
    display_name='spot-job',
    worker_pool_specs=[...],
    scheduling={"strategy": "SPOT", "max_wait_duration": "3600s"},
)
```

---

## GCS Operations

```bash
# Upload dataset
gsutil -m cp -r ./dataset gs://bucket/datasets/v1/

# Download outputs
gsutil -m cp -r gs://bucket/outputs/job-001 ./results/

# Sync checkpoints
gsutil -m rsync -r ./checkpoints gs://bucket/checkpoints/

# List files with sizes
gsutil ls -lh gs://bucket/outputs/job-001/

# Create bucket
gsutil mb -l us-central1 gs://my-training-bucket
```

---

## Environment Variables (auto-set by Vertex AI)

| Variable | Description |
|----------|-------------|
| `AIP_MODEL_DIR` | Output directory for models |
| `AIP_CHECKPOINT_DIR` | Checkpoint directory |
| `AIP_TENSORBOARD_LOG_DIR` | TensorBoard logs |
| `AIP_DATA_FORMAT` | Dataset format |
| `CLOUD_ML_JOB_ID` | Current job ID |
| `CLOUD_ML_PROJECT_ID` | Project ID |
| `CLOUD_ML_REGION` | Region |

---

## Quota Management

```bash
# Check GPU quotas
gcloud compute regions describe us-central1 \
  --format="table(quotas[].metric,quotas[].limit,quotas[].usage)"

# List available accelerators in a zone
gcloud compute accelerator-types list --filter="zone:us-central1-a"
```

---

## Troubleshooting

```bash
# Inside container — verify GPU
nvidia-smi
python -c "import torch; print(f'CUDA: {torch.cuda.is_available()}, GPUs: {torch.cuda.device_count()}')"

# Check disk space
df -h

# Test GCS connectivity
gsutil ls gs://bucket/

# Check auth
gcloud auth list
gcloud config list
```
