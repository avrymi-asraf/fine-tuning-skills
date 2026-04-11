# gcloud Cheat Sheet for ML Workloads

Quick reference for common gcloud commands used in ML training workflows.

## Authentication & Configuration

```bash
# Login (opens browser)
gcloud auth login

# Application Default Credentials (for SDKs)
gcloud auth application-default login

# View current configuration
gcloud config list

# Set project
gcloud config set project PROJECT_ID

# Set region/zone
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-a
```

## Multi-Project Management

```bash
# List configurations
gcloud config configurations list

# Create new configuration
gcloud config configurations create prod
gcloud config set project my-project-prod
gcloud config set compute/region us-east1

# Switch configurations
gcloud config configurations activate prod

# Show current config
gcloud config configurations describe prod
```

## Project & Billing

```bash
# List projects
gcloud projects list

# Create new project
gcloud projects create PROJECT_ID --name="Project Name"

# Link billing account
gcloud billing projects link PROJECT_ID --billing-account=XXXXXX-XXXXXX-XXXXXX

# List billing accounts
gcloud billing accounts list
```

## Service Accounts

```bash
# Create service account
gcloud iam service-accounts create SA_NAME --display-name="Display Name"

# Get service account email
SA_EMAIL="SA_NAME@PROJECT_ID.iam.gserviceaccount.com"

# Grant role to service account
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/aiplatform.user"

# Create and download key
gcloud iam service-accounts keys create key.json \
  --iam-account=$SA_EMAIL

# Impersonate service account
gcloud config set auth/impersonate_service_account $SA_EMAIL
```

## API Management

```bash
# List enabled APIs
gcloud services list --enabled

# Enable an API
gcloud services enable aiplatform.googleapis.com

# Check if API is enabled
gcloud services list --enabled | grep aiplatform
```

## IAM & Permissions

```bash
# Get IAM policy
gcloud projects get-iam-policy PROJECT_ID

# Add IAM binding
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:USER@example.com" \
  --role="roles/viewer"

# Remove IAM binding
gcloud projects remove-iam-policy-binding PROJECT_ID \
  --member="user:USER@example.com" \
  --role="roles/viewer"

# Test permissions
gcloud iam list-testable-permissions //cloudresourcemanager.googleapis.com/projects/PROJECT_ID
```

## Essential ML APIs

```bash
# Core ML APIs
gcloud services enable aiplatform.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable bigquery.googleapis.com
gcloud services enable notebooks.googleapis.com

# Container/Build APIs
gcloud services enable artifactregistry.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable container.googleapis.com

# Monitoring APIs
gcloud services enable logging.googleapis.com
gcloud services enable monitoring.googleapis.com
```

## GCS (Cloud Storage)

```bash
# Create bucket
gsutil mb -l us-central1 gs://BUCKET_NAME

# List buckets
gsutil ls

# Upload file
gsutil cp local-file.txt gs://BUCKET_NAME/

# Download file
gsutil cp gs://BUCKET_NAME/file.txt ./local-file.txt

# Sync directory
gsutil -m rsync -r ./local-dir gs://BUCKET_NAME/remote-dir

# Set bucket permissions
gsutil iam ch serviceAccount:SA_EMAIL:objectAdmin gs://BUCKET_NAME

# Enable versioning
gsutil versioning set on gs://BUCKET_NAME

# View bucket info
gsutil ls -L gs://BUCKET_NAME
```

## Artifact Registry

```bash
# Create repository
gcloud artifacts repositories create REPO_NAME \
  --repository-format=docker \
  --location=us-central1

# List repositories
gcloud artifacts repositories list

# Configure Docker auth
gcloud auth configure-docker us-central1-docker.pkg.dev

# List images
gcloud artifacts docker images list us-central1-docker.pkg.dev/PROJECT/REPO
```

## Vertex AI

```bash
# List custom jobs
gcloud ai custom-jobs list --region=us-central1

# Get job details
gcloud ai custom-jobs describe JOB_ID --region=us-central1

# Cancel job
gcloud ai custom-jobs cancel JOB_ID --region=us-central1

# View logs
gcloud ai custom-jobs stream-logs JOB_ID --region=us-central1

# List endpoints
gcloud ai endpoints list --region=us-central1

# List models
gcloud ai models list --region=us-central1

# Upload model
gcloud ai models upload --region=us-central1 \
  --display-name=my-model \
  --artifact-uri=gs://BUCKET_NAME/model \
  --container-image-uri=us-docker.pkg.dev/vertex-ai/prediction/tf2-cpu.2-12:latest
```

## Compute Quotas

```bash
# View regional quotas
gcloud compute regions describe us-central1 --format="table(quotas.metric:label=Metric, quotas.limit:label=Limit, quotas.usage:label=Usage)"

# List global quotas
gcloud compute project-info describe --project=PROJECT_ID
```

## Billing & Budgets

```bash
# List budgets
gcloud billing budgets list --billing-account=XXXXXX-XXXXXX-XXXXXX

# Create budget
gcloud billing budgets create \
  --billing-account=XXXXXX-XXXXXX-XXXXXX \
  --display-name="ML Budget" \
  --budget-amount=1000USD \
  --threshold-rule=percent=80

# View billing info
gcloud billing accounts get-iam-policy XXXXXX-XXXXXX-XXXXXX
```

## Cost Optimization

```bash
# View cost breakdown by service
gcloud billing accounts get-usage-report XXXXXX-XXXXXX-XXXXXX

# Export billing data to BigQuery
gcloud billing accounts export-bigquery \
  --billing-account=XXXXXX-XXXXXX-XXXXXX \
  --dataset-id=PROJECT:DATASET
```

## Useful Flags

| Flag | Description |
|------|-------------|
| `--project=PROJECT_ID` | Override default project |
| `--region=REGION` | Override default region |
| `--zone=ZONE` | Override default zone |
| `--format=json` | Output as JSON |
| `--format="value(field)"` | Extract specific field |
| `--filter="status=ACTIVE"` | Filter results |
| `--limit=10` | Limit results |
| `--sort-by=~createTime` | Sort by field (descending with ~) |
| `--quiet` | Suppress prompts |

## Format Examples

```bash
# Get just the project ID
gcloud config get-value project --format="value(projectId)"

# List projects as table
gcloud projects list --format="table(projectId, name, createTime)"

# Get service account email only
gcloud iam service-accounts list --format="value(email)" --filter="displayName:ml-training"

# List buckets with creation time
gsutil ls -L gs://BUCKET_NAME | grep "Time created"
```

## Environment Variables

```bash
# Use these to avoid passing flags repeatedly
export CLOUDSDK_CORE_PROJECT=PROJECT_ID
export CLOUDSDK_COMPUTE_REGION=us-central1
export CLOUDSDK_COMPUTE_ZONE=us-central1-a
```

## GPU Availability by Region

| Region | GPUs Available | Notes |
|--------|---------------|-------|
| `us-central1` | A100, L4, T4 | Good availability |
| `us-west1` | A100, L4, T4 | Good availability |
| `us-east1` | L4, T4 | Limited A100 |
| `europe-west4` | A100, L4, T4 | Netherlands |
| `europe-west1` | L4, T4 | Belgium |
| `asia-east1` | A100, T4 | Taiwan |

Check current availability:
```bash
gcloud compute accelerator-types list --filter="zone:us-central1-a"
```

## Quick Troubleshooting

```bash
# Check authentication
gcloud auth list

# Check active configuration
gcloud config list

# Refresh credentials
gcloud auth login --force

# Clear cached credentials
gcloud auth revoke

# Debug API calls
gcloud --log-http [command]

# Get verbose output
gcloud --verbosity=debug [command]
```
