---
name: cloud-infrastructure-setup
description: Set up and configure Google Cloud Platform infrastructure for ML training workloads. Use when installing gcloud CLI, configuring GCP projects, managing IAM roles and permissions for Vertex AI, setting environment variables for multi-project setups, enabling GCP APIs, or managing cloud costs for ML training. Covers authentication flows, project configuration, IAM roles, API enablement, environment management, and cost optimization including Spot VMs and budget alerts.
---

# Cloud Infrastructure Setup for ML

Set up and configure Google Cloud Platform infrastructure for machine learning training workloads.

## Scope

This skill covers:
- Installing and configuring gcloud CLI
- Authentication flows (user and service account)
- GCP project setup and configuration
- Enabling required APIs for ML workloads
- Environment variable management for multi-project setups
- IAM roles and permissions for Vertex AI
- Cost management (Spot VMs, budget alerts, quotas)

## Prerequisites

- Google Cloud account with billing enabled
- Local development environment (Linux, macOS, or Windows with WSL)
- Python 3.8+ installed (for Vertex AI SDK)
- Basic familiarity with shell scripting

## Quick Start

### 1. Install gcloud CLI

```bash
# macOS (ARM64/M1/M2)
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Linux (x86_64)
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz
tar -xf google-cloud-cli-linux-x86_64.tar.gz
./google-cloud-sdk/install.sh

# Initialize
gcloud init
```

### 2. Authenticate

```bash
# Interactive login (opens browser)
gcloud auth login

# Application default credentials (for code/SDKs)
gcloud auth application-default login
```

### 3. Set Project and Region

```bash
gcloud config set project YOUR_PROJECT_ID
gcloud config set compute/region us-central1
gcloud config set ai/region us-central1
```

### 4. Enable Required APIs

```bash
gcloud services enable aiplatform.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable storage.googleapis.com
```

## Workflows

### Initial GCP Setup for ML

Use `scripts/setup-gcloud.sh` for automated initial setup.

**Manual workflow:**

1. **Create/select project:**
   ```bash
   gcloud projects create my-ml-project --name="My ML Project"
   gcloud config set project my-ml-project
   ```

2. **Link billing account:**
   ```bash
   gcloud billing projects link my-ml-project --billing-account=XXXXXX-XXXXXX-XXXXXX
   ```

3. **Enable essential APIs:**
   ```bash
   # Core ML APIs
   gcloud services enable aiplatform.googleapis.com
   gcloud services enable compute.googleapis.com
   gcloud services enable storage.googleapis.com
   
   # Additional ML APIs
   gcloud services enable artifactregistry.googleapis.com
   gcloud services enable cloudbuild.googleapis.com
   gcloud services enable container.googleapis.com
   gcloud services enable containerregistry.googleapis.com
   gcloud services enable bigquery.googleapis.com
   ```

4. **Create service account for training:**
   ```bash
   gcloud iam service-accounts create ml-training-sa \
     --display-name="ML Training Service Account"
   
   # Grant Vertex AI User role
   gcloud projects add-iam-policy-binding my-ml-project \
     --member="serviceAccount:ml-training-sa@my-ml-project.iam.gserviceaccount.com" \
     --role="roles/aiplatform.user"
   
   # Grant Storage Admin for GCS access
   gcloud projects add-iam-policy-binding my-ml-project \
     --member="serviceAccount:ml-training-sa@my-ml-project.iam.gserviceaccount.com" \
     --role="roles/storage.admin"
   ```

### Environment Variable Management

Use `scripts/set-env.sh` template for consistent environment configuration.

**Recommended environment variables:**

```bash
# Project Configuration
export GCP_PROJECT_ID="my-ml-project"
export GCP_REGION="us-central1"
export GCP_ZONE="us-central1-a"

# Storage
export GCS_BUCKET="gs://my-ml-project-bucket"
export GCS_STAGING_BUCKET="gs://my-ml-project-staging"

# Training Configuration
export VERTEX_AI_LOCATION="us-central1"
export TRAINING_SERVICE_ACCOUNT="ml-training-sa@my-ml-project.iam.gserviceaccount.com"

# Container Registry
export ARTIFACT_REGISTRY="us-central1-docker.pkg.dev/my-ml-project/ml-images"
```

**Multi-project setup with gcloud configurations:**

```bash
# Create configuration for dev environment
gcloud config configurations create dev
gcloud config set project my-ml-project-dev
gcloud config set compute/region us-central1

# Create configuration for prod environment
gcloud config configurations create prod
gcloud config set project my-ml-project-prod
gcloud config set compute/region us-east1

# Switch between configurations
gcloud config configurations activate dev
gcloud config configurations activate prod
```

### IAM Roles for Vertex AI

**Essential roles for ML training:**

| Role | Purpose |
|------|---------|
| `roles/aiplatform.user` | Access to Vertex AI resources |
| `roles/storage.admin` | Full GCS bucket access |
| `roles/artifactregistry.reader` | Read container images |
| `roles/artifactregistry.writer` | Push container images |
| `roles/cloudbuild.builds.editor` | Run Cloud Build jobs |
| `roles/iam.serviceAccountUser` | Run jobs as service account |
| `roles/logging.logWriter` | Write training logs |
| `roles/monitoring.metricWriter` | Write metrics |

**Custom role for minimal permissions:**

```bash
# Create custom role for training only
gcloud iam roles create MlTrainingRunner \
  --project=my-ml-project \
  --title="ML Training Runner" \
  --description="Minimal permissions for ML training jobs" \
  --permissions=aiplatform.customJobs.create,aiplatform.customJobs.get,aiplatform.customJobs.list,aiplatform.customJobs.cancel,aiplatform.tensorboards.create,aiplatform.tensorboards.get,aiplatform.tensorboards.write,storage.objects.create,storage.objects.delete,storage.objects.get,storage.objects.list
```

Use `scripts/check-permissions.sh` to verify service account permissions.

### Cost Management

#### Spot VMs for Training

Spot VMs provide 60-91% cost savings but can be preempted.

**When to use:**
- Fault-tolerant training with checkpointing
- Batch processing jobs
- Development and experimentation

**Configuration:**
```bash
# In training job config (REST API)
{
  "scheduling": {
    "strategy": "SPOT"
  }
}

# With Vertex AI SDK
job.run(scheduling_strategy="SPOT")
```

**Best practices:**
- Always implement checkpointing
- Set up retry policies (up to 6 automatic retries)
- Use Elastic Horovod for distributed training
- Monitor preemption rates

#### Budget Alerts

```bash
# Create budget with alerts
gcloud billing budgets create \
  --billing-account=XXXXXX-XXXXXX-XXXXXX \
  --display-name="ML Training Budget" \
  --budget-amount=1000USD \
  --threshold-rule=percent=50 \
  --threshold-rule=percent=80 \
  --threshold-rule=percent=100

# With Pub/Sub notifications for programmatic handling
gcloud billing budgets create \
  --billing-account=XXXXXX-XXXXXX-XXXXXX \
  --display-name="ML Training Budget" \
  --budget-amount=1000USD \
  --threshold-rule=percent=80 \
  --pubsub-topic=projects/my-project/topics/budget-alerts
```

#### Quota Management

```bash
# View current quotas
gcloud compute project-info describe --project=my-ml-project

# Request quota increase
gcloud compute regions describe us-central1 \
  --project=my-ml-project \
  --format="table(quotas.metric:label=Metric, quotas.limit:label=Limit, quotas.usage:label=Usage)"
```

## Common Pitfalls and Solutions

### Authentication Issues

| Issue | Solution |
|-------|----------|
| `403 Forbidden` | Check IAM roles, verify `gcloud auth login` |
| `401 Unauthorized` | Refresh credentials: `gcloud auth login` |
| ADC not found | Run `gcloud auth application-default login` |
| Service account key expired | Rotate keys: `gcloud iam service-accounts keys create` |

### Quota Exhaustion

**Symptom:** `QUOTA_EXCEEDED` errors when submitting jobs

**Solutions:**
1. Check quota usage: Console → IAM & Admin → Quotas
2. Request increases in advance (can take 2-3 business days)
3. Use different regions for development
4. Implement queue-based job submission

### Cost Overruns

**Prevention:**
- Set up budget alerts at 50%, 80%, 100%
- Use Spot VMs for development
- Set max node counts for autoscaling
- Use labels for cost tracking
- Review billing reports weekly

### Multi-Project Confusion

**Best practice:** Use gcloud configurations

```bash
# List all configurations
gcloud config configurations list

# Show current config
gcloud config list

# Always verify project before expensive operations
gcloud config get-value project
```

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `scripts/setup-gcloud.sh` | Automated gcloud CLI installation and project setup |
| `scripts/set-env.sh` | Environment variable template |
| `scripts/check-permissions.sh` | Verify IAM permissions for service accounts |
| `scripts/enable-apis.sh` | Enable required GCP APIs |

## References

See `references/` directory:
- `gcloud-cheat-sheet.md` - Quick command reference
- `iam-roles-reference.md` - Detailed IAM role documentation
- `cost-management-guide.md` - Cost optimization strategies
- `troubleshooting.md` - Common issues and fixes

## Related Skills

- **Container Engineering for ML** - Docker setup, container registries
- **Cloud Storage & Artifact Management** - GCS operations, lifecycle policies
- **ML Training Pipeline** - Training job configuration
- **Cloud Job Orchestration** - Vertex AI job submission and monitoring

## External Documentation

- [Google Cloud SDK Documentation](https://cloud.google.com/sdk/docs)
- [Vertex AI IAM Permissions](https://docs.cloud.google.com/vertex-ai/docs/general/iam-permissions)
- [Spot VMs](https://cloud.google.com/compute/docs/instances/spot)
- [GCP Cost Management](https://cloud.google.com/cost-management)
- [ML on GCP Best Practices](https://docs.cloud.google.com/architecture/ml-on-gcp-best-practices)
