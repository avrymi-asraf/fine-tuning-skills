# Cloud ML Job Orchestration Cheat Sheet

## Vertex AI (gcloud)

### Job Management

```bash
# List all jobs in a region
gcloud ai custom-jobs list --region=us-central1

# Get job details
gcloud ai custom-jobs describe JOB_ID --region=us-central1

# Stream logs
gcloud ai custom-jobs stream-logs JOB_ID --region=us-central1

# Cancel a job
gcloud ai custom-jobs cancel JOB_ID --region=us-central1

# List jobs with filter
gcloud ai custom-jobs list --region=us-central1 \
  --filter="displayName:training-job AND state=JOB_STATE_RUNNING"
```

### Submit Job (CLI)

```bash
# Simple container job
gcloud ai custom-jobs create \
  --region=us-central1 \
  --display-name=my-job \
  --worker-pool-spec=machine-type=n1-standard-4,replica-count=1,container-image-uri=gcr.io/PROJECT/image:tag

# Job with GPU
gcloud ai custom-jobs create \
  --region=us-central1 \
  --display-name=gpu-job \
  --config=config.yaml

# Job with environment variables
gcloud ai custom-jobs create \
  --region=us-central1 \
  --display-name=env-job \
  --worker-pool-spec=machine-type=n1-standard-4,replica-count=1,container-image-uri=gcr.io/PROJECT/image:tag,env-vars=[KEY1=VALUE1,KEY2=VALUE2]
```

### Using Config File

```bash
# Create config.yaml
cat > config.yaml << 'EOF'
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
EOF

# Submit
gcloud ai custom-jobs create \
  --region=us-central1 \
  --display-name=my-job \
  --config=config.yaml
```

### Quota & Limits

```bash
# Check GPU quotas
gcloud compute regions describe us-central1 --format="table(quotas[].metric,quotas[].limit,quotas[].usage)"

# Request quota increase
gcloud alpha services quota update \
  --service=aiplatform.googleapis.com \
  --consumer=projects/PROJECT_ID \
  --metric=aiplatform.googleapis.com/custom_training_nvidia_a100_gpus \
  --value=16 \
  --force
```

---

## Vertex AI (Python SDK)

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
# Method 1: Using CustomContainerTrainingJob
job = aiplatform.CustomContainerTrainingJob(
    display_name='training-job',
    container_uri='gcr.io/PROJECT/training:v1',
)

job.run(
    machine_type='a2-highgpu-1g',
    accelerator_type='NVIDIA_TESLA_A100',
    accelerator_count=1,
    base_output_dir='gs://bucket/outputs/job-001',
    sync=False,
)

# Method 2: Using CustomJob directly
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
# Get job status
job = aiplatform.CustomJob.get('projects/PROJECT/locations/REGION/customJobs/JOB_ID')
print(f"State: {job.state}")

# Wait for completion
job.wait()

# List all jobs
jobs = aiplatform.CustomJob.list(filter='display_name="training-job*"')
for j in jobs:
    print(f"{j.display_name}: {j.state}")
```

---

## SageMaker (AWS CLI)

### Job Management

```bash
# List training jobs
aws sagemaker list-training-jobs

# Describe training job
aws sagemaker describe-training-job --training-job-name my-job

# Stop training job
aws sagemaker stop-training-job --training-job-name my-job
```

### Submit Job (Python)

```python
import sagemaker
from sagemaker.pytorch import PyTorch

estimator = PyTorch(
    entry_point='train.py',
    source_dir='.',
    role=sagemaker.get_execution_role(),
    framework_version='2.0.0',
    instance_count=1,
    instance_type='ml.p4d.24xlarge',
    use_spot_instances=True,
    max_wait=86400,
    checkpoint_s3_uri='s3://bucket/checkpoints',
)

estimator.fit('s3://bucket/dataset/')
```

---

## RunPod (Python)

### Create Pod

```python
import runpod

runpod.api_key = 'your-api-key'

pod = runpod.create_pod(
    name='training-job',
    image_name='gcr.io/PROJECT/training:v1',
    gpu_type_id='NVIDIA RTX A6000',
    cloud_type='COMMUNITY',
    container_disk_in_gb=50,
    volume_in_gb=500,
    env={'MODEL_NAME': 'llama-2-7b'},
)

print(f"Pod ID: {pod['id']}")
```

### Manage Pods

```python
# List pods
pods = runpod.get_pods()
for pod in pods:
    print(f"{pod['name']}: {pod['desiredStatus']}")

# Stop pod
runpod.stop_pod(pod_id)

# Resume pod
runpod.resume_pod(pod_id, gpu_count=1)

# Terminate pod
runpod.terminate_pod(pod_id)
```

---

## Docker & Container

### Build & Push

```bash
# Build training image
docker build -t gcr.io/PROJECT/training:v1 .

# Push to GCR
docker push gcr.io/PROJECT/training:v1

# Push to Artifact Registry
docker push REGION-docker.pkg.dev/PROJECT/REPO/training:v1

# Push to ECR
aws ecr get-login-password | docker login --username AWS --password-stdin ACCOUNT.dkr.ecr.REGION.amazonaws.com
docker push ACCOUNT.dkr.ecr.REGION.amazonaws.com/training:v1
```

### Test Locally

```bash
# Test with GPU
docker run --gpus all -it gcr.io/PROJECT/training:v1 python -c "import torch; print(torch.cuda.is_available())"

# Test training script
docker run --gpus all \
  -v $(pwd)/data:/data \
  -v $(pwd)/output:/output \
  gcr.io/PROJECT/training:v1 \
  python train.py --data /data --output /output
```

---

## GCS / S3 Operations

### Google Cloud Storage

```bash
# Upload dataset
gsutil -m cp -r ./dataset gs://bucket/datasets/v1/

# Download outputs
gsutil -m cp -r gs://bucket/outputs/job-001 ./results/

# Sync checkpoint directory
gsutil -m rsync -r ./checkpoints gs://bucket/checkpoints/job-001/

# List files
gsutil ls -lh gs://bucket/outputs/job-001/

# Make bucket
gsutil mb -l us-central1 gs://my-training-bucket
```

### AWS S3

```bash
# Upload
aws s3 cp --recursive ./dataset s3://bucket/datasets/v1/

# Download
aws s3 cp --recursive s3://bucket/outputs/job-001 ./results/

# Sync
aws s3 sync ./checkpoints s3://bucket/checkpoints/job-001/
```

---

## Environment Variables Reference

### Vertex AI Automatic Variables

| Variable | Description |
|----------|-------------|
| `AIP_MODEL_DIR` | Output directory for models |
| `AIP_CHECKPOINT_DIR` | Checkpoint directory |
| `AIP_TENSORBOARD_LOG_DIR` | TensorBoard logs |
| `AIP_DATA_FORMAT` | Dataset format |
| `CLOUD_ML_JOB_ID` | Current job ID |
| `CLOUD_ML_PROJECT_ID` | Project ID |
| `CLOUD_ML_REGION` | Region |

### SageMaker Automatic Variables

| Variable | Description |
|----------|-------------|
| `SM_MODEL_DIR` | Model output directory |
| `SM_CHANNEL_TRAINING` | Training data channel |
| `SM_CHANNEL_VALIDATION` | Validation data channel |
| `SM_OUTPUT_DATA_DIR` | Output data directory |
| `SM_CHECKPOINT_DIR` | Checkpoint directory |
| `SM_NUM_GPUS` | Number of GPUs |
| `SM_HOSTS` | List of hosts |
| `SM_CURRENT_HOST` | Current host name |

### RunPod Variables

| Variable | Description |
|----------|-------------|
| `RUNPOD_POD_ID` | Pod ID |
| `RUNPOD_GPU_COUNT` | Number of GPUs |
| `RUNPOD_API_KEY` | API key (if provided) |

---

## Troubleshooting Commands

### Check GPU Availability

```bash
# Inside container
nvidia-smi
nvidia-smi -L  # List GPUs
nvidia-smi dmon  # Monitor GPU usage

# Check CUDA version
nvcc --version
python -c "import torch; print(f'CUDA: {torch.cuda.is_available()}, GPUs: {torch.cuda.device_count()}')"
```

### Disk Space

```bash
# Check disk usage
df -h

# Check specific directory
du -sh /gcs/*
du -sh /tmp/*

# Clean up
rm -rf /tmp/cache/*
```

### Network Issues

```bash
# Test GCS connectivity
gsutil ls gs://bucket/

# Check DNS
curl -I https://storage.googleapis.com

# Check IAM
gcloud auth list
gcloud auth print-access-token
```

---

## Cost Estimation

### Calculate Training Cost (Manual)

```bash
# Vertex AI example
MACHINE_TYPE="a2-highgpu-1g"
HOURS=24
HOURLY_RATE=3.67  # Check current pricing

echo "Estimated cost: $(( HOURS * HOURLY_RATE )) USD"

# With spot (60-91% discount)
SPOT_RATE=$(echo "$HOURLY_RATE * 0.3" | bc)
echo "Spot cost: $(echo "$HOURS * $SPOT_RATE" | bc) USD"
```

### Using Scripts

```bash
# Estimate before running
python scripts/cost-estimate.py --machine-type a2-highgpu-1g --hours 24 --use-spot

# Compare platforms
python scripts/cost-estimate.py --platform vertex --machine-type a2-highgpu-1g --hours 24
python scripts/cost-estimate.py --platform sagemaker --instance-type ml.p4d.24xlarge --hours 24
python scripts/cost-estimate.py --platform runpod --gpu-type "NVIDIA A100 80GB" --hours 24
```

---

## Workflow Templates

### Full Training Workflow

```bash
#!/bin/bash
set -e

# 1. Estimate cost
python scripts/cost-estimate.py \
  --machine-type a2-highgpu-1g \
  --hours 12 \
  --use-spot

# 2. Build and push image
gcloud builds submit --tag gcr.io/$PROJECT/training:$TAG .

# 3. Submit job with spot
python scripts/submit-training-job.py \
  --config configs/training.yaml \
  --container-uri gcr.io/$PROJECT/training:$TAG \
  --use-spot \
  --save-job-id .last_job_id

# 4. Monitor
JOB_ID=$(cat .last_job_id)
./scripts/monitor-job.sh $JOB_ID

# 5. Download results
gsutil -m cp -r gs://$BUCKET/outputs/$JOB_ID ./results/
```

### Spot Job with Retry

```bash
#!/bin/bash
set -e

./scripts/handle-preemption.sh \
  --config configs/training-spot.yaml \
  --max-retries 10 \
  --region us-central1
```
