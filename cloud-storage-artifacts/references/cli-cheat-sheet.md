# Cloud Storage CLI Cheat Sheet

## Quick Command Mapping

| Operation | GCS (gcloud) | GCS (gsutil) | S3 (aws) | Azure |
|-----------|--------------|--------------|----------|-------|
| Create bucket | `gcloud storage buckets create` | `gsutil mb` | `aws s3 mb` | `az storage container create` |
| List buckets | `gcloud storage buckets list` | `gsutil ls` | `aws s3 ls` | `az storage container list` |
| Upload file | `gcloud storage cp` | `gsutil cp` | `aws s3 cp` | `az storage blob upload` |
| Download | `gcloud storage cp` | `gsutil cp` | `aws s3 cp` | `az storage blob download` |
| Sync | `gcloud storage rsync` | `gsutil rsync` | `aws s3 sync` | `az storage blob sync` |
| Delete | `gcloud storage rm` | `gsutil rm` | `aws s3 rm` | `az storage blob delete` |

---

## Google Cloud Storage

### gcloud storage (Recommended)

```bash
# Buckets
gcloud storage buckets create gs://BUCKET_NAME --location=us-central1
gcloud storage buckets list
gcloud storage buckets describe gs://BUCKET_NAME
gcloud storage buckets delete gs://BUCKET_NAME

# Objects
gcloud storage cp file.txt gs://BUCKET/path/
gcloud storage cp gs://BUCKET/file.txt ./
gcloud storage cp -r local-dir/ gs://BUCKET/path/
gcloud storage mv gs://BUCKET/old gs://BUCKET/new
gcloud storage rm gs://BUCKET/file
gcloud storage rm -r gs://BUCKET/dir/

# Sync
gcloud storage rsync -r local/ gs://BUCKET/remote/
gcloud storage rsync -r gs://BUCKET/remote/ local/

# List
gcloud storage ls gs://BUCKET/
gcloud storage ls -r gs://BUCKET/      # Recursive
gcloud storage ls -l gs://BUCKET/      # With details

# Copy between buckets
gcloud storage cp gs://SRC/file gs://DST/file

# With options
gcloud storage cp --storage-class=NEARLINE file gs://BUCKET/
gcloud storage cp --parallelism=8 large-file gs://BUCKET/
gcloud storage cp --content-type=application/json data.json gs://BUCKET/

# Metadata
gcloud storage objects describe gs://BUCKET/file
gcloud storage objects update gs://BUCKET/file --custom-metadata=key=value

# Lifecycle
gcloud storage buckets update gs://BUCKET --lifecycle-file=policy.json
gcloud storage buckets describe gs://BUCKET --format="value(lifecycle_config)"
```

### gsutil (Legacy)

```bash
# Buckets
gsutil mb -l us-central1 gs://BUCKET
gsutil rb gs://BUCKET                    # Remove bucket

# Basic operations
gsutil cp file.txt gs://BUCKET/
gsutil cp gs://BUCKET/file.txt ./
gsutil cp -r dir/ gs://BUCKET/
gsutil mv gs://BUCKET/old gs://BUCKET/new
gsutil rm gs://BUCKET/file
gsutil rm -r gs://BUCKET/dir/

# Parallel operations
gsutil -m cp -r dir/ gs://BUCKET/        # Multi-threaded

# Sync
gsutil rsync -r local/ gs://BUCKET/remote/
gsutil rsync -d -r local/ gs://BUCKET/   # Delete extraneous

# List
gsutil ls gs://BUCKET/
gsutil ls -L gs://BUCKET/file            # Detailed info

# Metadata
gsutil stat gs://BUCKET/file
gsutil setmeta -h "Content-Type:application/json" gs://BUCKET/file

# ACLs
gsutil acl get gs://BUCKET/file
gsutil acl ch -u user@example.com:R gs://BUCKET/file

# Storage class
gsutil cp -s NEARLINE file gs://BUCKET/
gsutil rewrite -s COLDLINE gs://BUCKET/file

# Lifecycle
gsutil lifecycle set policy.json gs://BUCKET
gsutil lifecycle get gs://BUCKET

# Size/usage
gsutil du -sh gs://BUCKET/               # Total size
gsutil du -h gs://BUCKET/dir/            # Per-object sizes
```

---

## Amazon S3

```bash
# Buckets
aws s3 mb s3://BUCKET --region us-east-1
aws s3 ls
aws s3 rb s3://BUCKET                    # Remove empty bucket
aws s3 rb s3://BUCKET --force            # Remove with contents

# Objects
aws s3 cp file.txt s3://BUCKET/path/
aws s3 cp s3://BUCKET/file.txt ./
aws s3 cp -r local/ s3://BUCKET/path/
aws s3 mv s3://BUCKET/old s3://BUCKET/new
aws s3 rm s3://BUCKET/file
aws s3 rm --recursive s3://BUCKET/dir/

# Sync
aws s3 sync local/ s3://BUCKET/remote/
aws s3 sync s3://BUCKET/remote/ local/
aws s3 sync --delete local/ s3://BUCKET/ # Delete extraneous

# With options
aws s3 cp --storage-class STANDARD_IA file s3://BUCKET/
aws s3 cp --metadata key=value file s3://BUCKET/
aws s3 cp --content-type application/json file s3://BUCKET/

# List
aws s3 ls s3://BUCKET/
aws s3 ls --recursive s3://BUCKET/
aws s3 ls --human-readable --summarize --recursive s3://BUCKET/

# Presigned URLs
aws s3 presign s3://BUCKET/file --expires-in 3600

# API operations (advanced)
aws s3api put-object --bucket BUCKET --key file.txt --body file.txt
aws s3api get-object --bucket BUCKET --key file.txt output.txt
aws s3api head-object --bucket BUCKET --key file.txt

# Multipart upload (large files)
aws s3 cp large-file s3://BUCKET/ --multipart-threshold 100MB

# Lifecycle
aws s3api put-bucket-lifecycle-configuration \
    --bucket BUCKET --lifecycle-configuration file://policy.json

# Storage class transitions
aws s3 cp s3://BUCKET/file s3://BUCKET/file --storage-class GLACIER
```

---

## Azure Blob Storage

```bash
# Containers
az storage container create --name CONTAINER --account-name STORAGE
az storage container list --account-name STORAGE
az storage container delete --name CONTAINER --account-name STORAGE

# Blobs
az storage blob upload \
    --container-name CONTAINER \
    --file local.txt \
    --name remote.txt \
    --account-name STORAGE

az storage blob download \
    --container-name CONTAINER \
    --name remote.txt \
    --file local.txt \
    --account-name STORAGE

az storage blob delete \
    --container-name CONTAINER \
    --name remote.txt \
    --account-name STORAGE

# Batch operations
az storage blob upload-batch \
    --destination CONTAINER \
    --source local-dir/ \
    --account-name STORAGE

az storage blob download-batch \
    --source CONTAINER \
    --destination local-dir/ \
    --pattern "prefix/*" \
    --account-name STORAGE

az storage blob delete-batch \
    --source CONTAINER \
    --pattern "prefix/*" \
    --account-name STORAGE

# Sync
az storage blob sync \
    --container CONTAINER \
    --source local-dir/ \
    --account-name STORAGE

# List
az storage blob list \
    --container-name CONTAINER \
    --account-name STORAGE \
    --output table

# Copy between accounts
az storage blob copy start \
    --source-uri "https://SRC.blob.core.windows.net/CONTAINER/file" \
    --destination-container CONTAINER \
    --destination-blob file \
    --account-name DST_STORAGE

# Lifecycle
az storage account management-policy create \
    --account-name STORAGE \
    --resource-group RG \
    --policy @policy.json
```

---

## GCS FUSE

```bash
# Mount bucket locally
gcsfuse BUCKET_NAME ~/mount-point

# Mount read-only
gcsfuse -o ro BUCKET_NAME ~/mount-point

# Mount with custom permissions
gcsfuse --file-mode=644 --dir-mode=755 BUCKET_NAME ~/mount-point

# Mount with caching
gcsfuse --stat-cache-ttl 1h --type-cache-ttl 1h BUCKET_NAME ~/mount-point

# Foreground mode (for debugging)
gcsfuse --foreground BUCKET_NAME ~/mount-point

# Unmount (Linux)
fusermount -u ~/mount-point

# Unmount (macOS)
umount ~/mount-point

# Docker usage
gcsfuse --key-file=/secrets/key.json BUCKET_NAME /gcs/data
```

---

## Common Patterns

### Upload with Progress
```bash
# GCS - progress shown by default
gcloud storage cp large-file gs://BUCKET/

# S3 - use progress
aws s3 cp large-file s3://BUCKET/

# Azure - use azcopy for progress
azcopy copy local-file "https://STORAGE.blob.core.windows.net/CONTAINER/file?SAS"
```

### Resume Interrupted Transfer
```bash
# Most tools support automatic resume for multipart uploads
# GCS
gcloud storage cp large-file gs://BUCKET/

# S3 - automatic for multipart
aws s3 cp large-file s3://BUCKET/

# rsync for any resume
rsync -avP --inplace local/file remote:/path/
```

### Stream Data
```bash
# Upload from stdin
cat data.txt | gcloud storage cp - gs://BUCKET/data.txt
cat data.txt | aws s3 cp - s3://BUCKET/data.txt

# Download to stdout
gcloud storage cp gs://BUCKET/data.txt - | process
aws s3 cp s3://BUCKET/data.txt - | process
```

### Compression
```bash
# Compress on upload
tar -czf - data/ | gcloud storage cp - gs://BUCKET/data.tar.gz
tar -czf - data/ | aws s3 cp - s3://BUCKET/data.tar.gz

# With gzip content-encoding
gcloud storage cp -Z file.json gs://BUCKET/  # -Z = gzip
```

### Find and Delete Old Files
```bash
# GCS - using lifecycle (recommended)
# Or manually:
gsutil ls -r gs://BUCKET/ | xargs -I {} gsutil ls -L {} | grep -B2 "30 days ago"

# S3
aws s3api list-objects --bucket BUCKET --query 'Contents[?LastModified<`'$(date -d '30 days ago' +%Y-%m-%d)'`].[Key]' --output text | xargs -I {} aws s3 rm s3://BUCKET/{}
```

---

## Environment Variables

### GCS
```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
export CLOUDSDK_CORE_PROJECT=project-id
```

### S3
```bash
export AWS_ACCESS_KEY_ID=xxx
export AWS_SECRET_ACCESS_KEY=xxx
export AWS_DEFAULT_REGION=us-east-1
```

### Azure
```bash
export AZURE_STORAGE_ACCOUNT=storageaccount
export AZURE_STORAGE_KEY=xxx
export AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=https;..."
```
