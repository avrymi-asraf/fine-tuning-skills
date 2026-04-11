# Cloud Storage & Artifact Management

**Purpose:** Manage ML artifacts, checkpoints, and training outputs across cloud storage platforms (GCS, S3, Azure Blob).

**Scope:**
- Creating and configuring cloud storage buckets
- Uploading/downloading ML artifacts
- Organizing training outputs (checkpoints, models, logs)
- Lifecycle policies and auto-cleanup
- Local/cloud sync workflows
- Bucket mounting in containers
- Cost optimization strategies

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Storage Fundamentals](#storage-fundamentals)
4. [Bucket Organization for ML](#bucket-organization-for-ml)
5. [CLI Tools](#cli-tools)
6. [Lifecycle Management](#lifecycle-management)
7. [Mounting Buckets](#mounting-buckets)
8. [Cost Optimization](#cost-optimization)
9. [Common Pitfalls](#common-pitfalls)
10. [Scripts](#scripts)
11. [References](#references)

---

## Prerequisites

### Required Tools

**Google Cloud Storage:**
```bash
# Install gcloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Initialize and authenticate
gcloud init
gcloud auth login
gcloud auth application-default login
```

**AWS S3:**
```bash
# Install AWS CLI
pip install awscli

# Configure credentials
aws configure
```

**Azure Blob:**
```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login
az login
```

**GCS FUSE (for mounting):**
```bash
# Ubuntu/Debian
echo "deb https://packages.cloud.google.com/apt gcsfuse-bionic main" | sudo tee /etc/apt/sources.list.d/gcsfuse.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-get update && sudo apt-get install gcsfuse

# macOS (via Homebrew)
brew install gcsfuse
```

### Authentication Setup

**GCS Service Account:**
```bash
# Create service account for CI/CD
gcloud iam service-accounts create storage-sa \
    --display-name="Storage Service Account"

# Grant storage roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:storage-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/storage.objectAdmin"

# Download key
gcloud iam service-accounts keys create storage-sa-key.json \
    --iam-account=storage-sa@$PROJECT_ID.iam.gserviceaccount.com

export GOOGLE_APPLICATION_CREDENTIALS="$PWD/storage-sa-key.json"
```

---

## Quick Start

```bash
# Create a bucket for ML artifacts
gcloud storage buckets create gs://my-project-ml-artifacts \
    --location=us-central1 \
    --default-storage-class=STANDARD \
    --uniform-bucket-level-access

# Upload training artifacts
gcloud storage cp -r ./outputs/ gs://my-project-ml-artifacts/experiments/run-001/

# Download model checkpoint
gcloud storage cp gs://my-project-ml-artifacts/experiments/run-001/checkpoint-final.pt ./

# Sync local directory with cloud
gcloud storage rsync -r ./logs/ gs://my-project-ml-artifacts/logs/
```

---

## Storage Fundamentals

### Storage Class Comparison

| Class | Access Frequency | Min Storage | Retrieval Fee | Best For |
|-------|-----------------|-------------|---------------|----------|
| **STANDARD** | Frequent | None | None | Active training data, recent checkpoints |
| **NEARLINE** | <1x/month | 30 days | Low | Model registry, previous experiments |
| **COLDLINE** | <1x/quarter | 90 days | Medium | Archived experiments, old logs |
| **ARCHIVE** | <1x/year | 365 days | High | Long-term compliance, final models |
| **AUTOMATIC** | Varies | None | None | ML workloads with varying access |

**Notes:**
- **Early deletion fees** apply if you delete before minimum storage duration
- **Retrieval fees** apply when accessing non-STANDARD classes
- **AUTOMATIC** class uses ML to optimize placement (GCS only)

### Multi-Cloud Comparison

| Feature | GCS | S3 | Azure Blob |
|---------|-----|-----|------------|
| Standard | STANDARD | S3 Standard | Hot |
| Infrequent | NEARLINE | S3 Standard-IA | Cool |
| Archive | COLDLINE/ARCHIVE | S3 Glacier | Archive |
| Auto-tiering | AUTOMATIC | S3 Intelligent-Tiering | Cool Tiers |
| FUSE mounting | GCS FUSE | s3fs | blobfuse2 |

---

## Bucket Organization for ML

### Recommended Hierarchy

```
ml-artifacts-bucket/
├── datasets/
│   ├── raw/
│   │   ├── dataset-a/
│   │   └── dataset-b/
│   └── processed/
│       ├── dataset-a/v1.0/
│       └── dataset-b/v1.0/
├── models/
│   ├── registry/
│   │   ├── model-a/v1.0/
│   │   ├── model-a/v1.1/
│   │   └── model-b/v2.0/
│   └── experiments/
│       ├── 2024-01-15-experiment-name/
│       │   ├── config.yaml
│       │   ├── checkpoints/
│       │   │   ├── checkpoint-1000.pt
│       │   │   └── checkpoint-2000.pt
│       │   ├── final/
│       │   │   ├── model.pt
│   │   │   │   └── tokenizer.json
│   │   │   └── metrics.json
│   │   └── logs/
│   └── └── 2024-01-16-another-experiment/
├── checkpoints/
│   ├── temporary/          # Short-lived, auto-deleted
│   └── important/          # Keep longer
└── logs/
    ├── tensorboard/
    └── training/
```

### Naming Conventions

```bash
# Experiment folders: YYYY-MM-DD-descriptive-name
gs://bucket/experiments/2024-01-15-llama-7b-fine-tune/
gs://bucket/experiments/2024-01-16-llama-7b-lora-4bit/

# Checkpoints: checkpoint-{step}.ext
checkpoint-1000.pt
checkpoint-2000.pt
checkpoint-final.pt

# Models: model-{version}-{qualifier}
model-v1.0-base.pt
model-v1.1-finetuned.pt
model-v2.0-merged.pt

# Configs: Include timestamp/hash
config-20240115-abc123.yaml
```

---

## CLI Tools

### GCS: gcloud storage (Recommended)

Google's modern CLI - faster than gsutil with better UX.

```bash
# Buckets
gcloud storage buckets create gs://BUCKET_NAME --location=us-central1
gcloud storage buckets list
gcloud storage buckets describe gs://BUCKET_NAME
gcloud storage buckets delete gs://BUCKET_NAME

# Objects
gcloud storage cp local.file gs://bucket/path/
gcloud storage cp gs://bucket/file local.file
gcloud storage cp -r local-dir/ gs://bucket/path/
gcloud storage mv gs://bucket/old gs://bucket/new
gcloud storage rm gs://bucket/file
gcloud storage rm -r gs://bucket/dir/

# Sync (rsync)
gcloud storage rsync -r local-dir/ gs://bucket/dir/
gcloud storage rsync -r gs://bucket/dir/ local-dir/

# List with details
gcloud storage ls -l gs://bucket/
gcloud storage ls -r gs://bucket/  # Recursive

# Copy between buckets
gcloud storage cp gs://src-bucket/file gs://dst-bucket/file

# Streaming
cat data.txt | gcloud storage cp - gs://bucket/data.txt
gcloud storage cp gs://bucket/data.txt - | wc -l
```

### GCS: gsutil (Legacy)

Still widely used but being deprecated.

```bash
# Same commands, different syntax
gsutil mb -l us-central1 gs://bucket
gsutil ls -L gs://bucket
gsutil cp -r local/ gs://bucket/
gsutil rm -r gs://bucket/dir/

# Parallel uploads (gsutil advantage)
gsutil -m cp -r local/ gs://bucket/  # -m = multi-threaded

# Set metadata
gsutil setmeta -h "Content-Type:application/json" gs://bucket/file

# ACL management
gsutil acl ch -u user@example.com:R gs://bucket/file
```

### AWS S3

```bash
# Buckets
aws s3 mb s3://bucket-name --region us-east-1
aws s3 ls
aws s3 rb s3://bucket-name

# Objects
aws s3 cp local.file s3://bucket/path/
aws s3 cp s3://bucket/file local.file
aws s3 cp -r local-dir/ s3://bucket/path/
aws s3 mv s3://bucket/old s3://bucket/new
aws s3 rm s3://bucket/file
aws s3 rm --recursive s3://bucket/dir/

# Sync
aws s3 sync local-dir/ s3://bucket/dir/
aws s3 sync s3://bucket/dir/ local-dir/

# Presigned URLs
aws s3 presign s3://bucket/file --expires-in 3600
```

### Azure Blob

```bash
# Containers
az storage container create --name container --account-name mystorage
az storage container list --account-name mystorage

# Blobs
az storage blob upload --container container --file local.file --name path/file
az storage blob download --container container --name path/file --file local.file
az storage blob delete --container container --name path/file

# Sync
az storage blob sync --container container --source local-dir/

# List
az storage blob list --container container --output table
```

---

## Lifecycle Management

### GCS Lifecycle Policies

Create `lifecycle.json`:
```json
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {
          "age": 30,
          "matchesPrefix": ["experiments/temp/"]
        }
      },
      {
        "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
        "condition": {
          "age": 7,
          "matchesPrefix": ["checkpoints/"],
          "numNewerVersions": 3
        }
      },
      {
        "action": {"type": "SetStorageClass", "storageClass": "COLDLINE"},
        "condition": {
          "age": 90,
          "matchesPrefix": ["experiments/"]
        }
      },
      {
        "action": {"type": "Delete"},
        "condition": {
          "age": 365,
          "matchesPrefix": ["logs/"]
        }
      }
    ]
  }
}
```

Apply:
```bash
gcloud storage buckets update gs://bucket --lifecycle-file=lifecycle.json

# View current policy
gcloud storage buckets describe gs://bucket --format="value(lifecycle_config)"

# Clear all rules
gcloud storage buckets update gs://bucket --clear-lifecycle
```

### S3 Lifecycle Policies

```json
{
  "Rules": [
    {
      "ID": "DeleteTempCheckpoints",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "checkpoints/temp/"
      },
      "Expiration": {
        "Days": 7
      }
    },
    {
      "ID": "TransitionToIA",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "experiments/"
      },
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        }
      ]
    }
  ]
}
```

Apply:
```bash
aws s3api put-bucket-lifecycle-configuration \
    --bucket my-bucket \
    --lifecycle-configuration file://lifecycle.json
```

### Azure Lifecycle Management

```json
{
  "rules": [
    {
      "name": "deleteOldLogs",
      "enabled": true,
      "type": "Lifecycle",
      "definition": {
        "filters": {
          "blobTypes": ["blockBlob"],
          "prefixMatch": ["logs/"]
        },
        "actions": {
          "baseBlob": {
            "delete": { "daysAfterModificationGreaterThan": 365 }
          }
        }
      }
    }
  ]
}
```

Apply:
```bash
az storage account management-policy create \
    --account-name mystorage \
    --policy @lifecycle.json
```

---

## Mounting Buckets

### GCS FUSE

**Local Mount:**
```bash
# Create mount point
mkdir -p ~/gcs/bucket-name

# Mount (read-write)
gcsfuse bucket-name ~/gcs/bucket-name

# Mount read-only
gcsfuse -o ro bucket-name ~/gcs/bucket-name

# Mount with specific permissions
gcsfuse --file-mode=755 --dir-mode=755 bucket-name ~/gcs/bucket-name

# Unmount
fusermount -u ~/gcs/bucket-name  # Linux
umount ~/gcs/bucket-name          # macOS
```

**Docker Mount:**
```dockerfile
FROM python:3.11

# Install GCS FUSE
RUN apt-get update && apt-get install -y \
    curl gnupg lsb-release fuse \
    && gcsfuse_repo=gcsfuse-$(lsb_release -c -s) \
    && echo "deb https://packages.cloud.google.com/apt $gcsfuse_repo main" | tee /etc/apt/sources.list.d/gcsfuse.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
    && apt-get update && apt-get install -y gcsfuse

# Mount point
RUN mkdir -p /gcs/models

# Entrypoint script mounts and runs
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
```

```bash
# entrypoint.sh
#!/bin/bash
gcsfuse --foreground --key-file=/secrets/key.json \
    ${GCS_BUCKET} /gcs/models &
sleep 2  # Wait for mount
exec "$@"
```

**Kubernetes (GKE):**
```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: training
    image: gcr.io/project/training:latest
    volumeMounts:
    - name: gcs-volume
      mountPath: /gcs/data
  volumes:
  - name: gcs-volume
    csi:
      driver: gcsfuse.csi.storage.gke.io
      volumeAttributes:
        bucketName: my-bucket
        mountOptions: "implicit-dirs,file-mode=755,dir-mode=755"
```

### S3 FUSE (s3fs)

```bash
# Install
sudo apt-get install s3fs

# Credentials
echo ACCESS_KEY_ID:SECRET_KEY > ~/.passwd-s3fs
chmod 600 ~/.passwd-s3fs

# Mount
mkdir -p ~/s3/bucket
s3fs my-bucket ~/s3/bucket -o passwd_file=~/.passwd-s3fs

# Unmount
fusermount -u ~/s3/bucket
```

### Azure Blob FUSE (blobfuse2)

```bash
# Install
wget https://github.com/Azure/azure-storage-fuse/releases/download/blobfuse2-2.2.1/blobfuse2-2.2.1-Debian-11.0.x86_64.deb
sudo dpkg -i blobfuse2-2.2.1-Debian-11.0.x86_64.deb

# Config file
mkdir -p ~/.blobfuse2
```

---

## Cost Optimization

### Strategies for ML Workloads

1. **Tiered Storage by Age**
   - Recent checkpoints → STANDARD
   - Week-old checkpoints → NEARLINE/S3 IA
   - Month-old artifacts → COLDLINE/Glacier
   - Final models → Keep in STANDARD (if accessed)

2. **Clean Up Temp Files**
   - Delete failed experiment checkpoints immediately
   - Auto-delete `/temp/` and `/scratch/` prefixes

3. **Compression**
   ```bash
   # Compress before upload
   tar -czf - model_dir/ | gcloud storage cp - gs://bucket/model.tar.gz
   
   # Upload with gzip
   gcloud storage cp -Z large_file.json gs://bucket/  # -Z = gzip
   ```

4. **Regional Selection**
   - Use same region as compute to avoid egress
   - Multi-region only if needed for availability

5. **Object Size Optimization**
   - GCS: Use composite uploads for >150MB
   - S3: Multipart upload for >100MB
   - Azure: Block blob for large files

### Cost Estimation

```bash
# GCS: Get bucket size
gsutil du -sh gs://bucket

# S3: Get bucket size
aws s3 ls s3://bucket --recursive --human-readable --summarize

# Azure: Get container size
az storage blob list --container container --query "[].properties.contentLength" | jq add
```

---

## Common Pitfalls

### 1. Egress Charges
**Problem:** Downloading data to different region/Internet costs $$  
**Solution:** Keep compute and storage in same region

### 2. Early Deletion Fees
**Problem:** Deleting NEARLINE objects before 30 days  
**Fix:** Use STANDARD for short-lived data, transition only after 30 days

### 3. Versioning Bloat
**Problem:** Enabled versioning, costs balloon  
```bash
# Check if versioning is on
gcloud storage buckets describe gs://bucket --format="value(versioning.enabled)"

# Set lifecycle to clean old versions
{
  "action": {"type": "Delete"},
  "condition": {"numNewerVersions": 5}
}
```

### 4. Large Directory Listings
**Problem:** `ls` on bucket with 1M+ files is slow  
**Fix:** Use prefixes, don't list entire bucket
```bash
# Good
gcloud storage ls gs://bucket/experiments/2024-01/

# Bad
gcloud storage ls gs://bucket/  # Might timeout
```

### 5. Mount Performance
**Problem:** GCS FUSE is slower than native filesystem  
**Fix:** 
- Cache frequently accessed files locally
- Use sequential reads when possible
- Increase `--stat-cache-ttl` and `--type-cache-ttl`

### 6. Silent Failures in Scripts
**Problem:** `cp` fails but script continues  
**Fix:**
```bash
set -euo pipefail
gcloud storage cp ... || { echo "Upload failed"; exit 1; }
```

---

## Scripts

See `scripts/` directory for:
- `setup-bucket.sh` - Create and configure buckets
- `upload-training-artifacts.sh` - Upload with metadata
- `download-model.sh` - Download with validation
- `cleanup-old-runs.sh` - Clean up old experiments
- `sync-directory.sh` - Bidirectional sync

---

## References

See `references/` directory for:
- Official documentation links
- Storage class comparison tables
- CLI command cheat sheets
