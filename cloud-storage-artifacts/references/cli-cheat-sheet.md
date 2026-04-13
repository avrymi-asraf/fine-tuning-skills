# GCS CLI Cheat Sheet

## gcloud storage (Recommended)

```bash
# Buckets
gcloud storage buckets create gs://BUCKET --location=us-central1
gcloud storage buckets list
gcloud storage buckets describe gs://BUCKET
gcloud storage buckets delete gs://BUCKET

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
gcloud storage ls -r gs://BUCKET/             # Recursive
gcloud storage ls -l gs://BUCKET/             # With details

# Copy between buckets
gcloud storage cp gs://SRC/file gs://DST/file

# Options
gcloud storage cp --storage-class=NEARLINE file gs://BUCKET/
gcloud storage cp --parallelism=8 large-file gs://BUCKET/
gcloud storage cp --content-type=application/json data.json gs://BUCKET/

# Metadata
gcloud storage objects describe gs://BUCKET/file
gcloud storage objects update gs://BUCKET/file --custom-metadata=key=value

# Lifecycle
gcloud storage buckets update gs://BUCKET --lifecycle-file=policy.json
gcloud storage buckets describe gs://BUCKET --format="value(lifecycle_config)"
gcloud storage buckets update gs://BUCKET --clear-lifecycle
```

## gsutil (Legacy — still usable, being deprecated)

```bash
# Buckets
gsutil mb -l us-central1 gs://BUCKET
gsutil rb gs://BUCKET

# Objects (same verbs, different syntax)
gsutil cp file.txt gs://BUCKET/
gsutil cp -r dir/ gs://BUCKET/
gsutil rm -r gs://BUCKET/dir/

# Parallel (gsutil advantage for bulk operations)
gsutil -m cp -r dir/ gs://BUCKET/              # Multi-threaded

# Sync
gsutil rsync -r local/ gs://BUCKET/remote/
gsutil rsync -d -r local/ gs://BUCKET/         # Delete extraneous

# Metadata
gsutil stat gs://BUCKET/file
gsutil setmeta -h "Content-Type:application/json" gs://BUCKET/file

# Storage class
gsutil rewrite -s COLDLINE gs://BUCKET/file

# Size
gsutil du -sh gs://BUCKET/                     # Total size
```

## Common Patterns

### Upload with Git Metadata Tagging
```bash
# Single file
gcloud storage cp model.pt gs://BUCKET/models/ \
  --custom-metadata=git-commit=$(git rev-parse --short HEAD) \
  --custom-metadata=git-branch=$(git rev-parse --abbrev-ref HEAD) \
  --custom-metadata=upload-time=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Recursive directory upload
gcloud storage cp -r ./experiment-output/ gs://BUCKET/experiments/run-001/ \
  --custom-metadata=git-commit=$(git rev-parse --short HEAD)

# Upload with specific storage class
gcloud storage cp --storage-class=NEARLINE ./old-data gs://BUCKET/archive/
```

### Compress and Upload
```bash
# Compress a directory, then upload the archive
tar -czf - ./checkpoints/ | gcloud storage cp - gs://BUCKET/checkpoints/run-001.tar.gz

# gzip transport encoding (smaller transfer, stored decompressed)
gcloud storage cp -Z file.json gs://BUCKET/
```

### Download
```bash
# Single file
gcloud storage cp gs://BUCKET/models/model.pt ./model.pt

# Recursive directory
gcloud storage cp -r gs://BUCKET/experiments/run-001/ ./local-run/

# Download and verify checksum
gcloud storage cp gs://BUCKET/model.pt ./model.pt
sha256sum ./model.pt    # compare with expected hash

# Download and extract archive
gcloud storage cp gs://BUCKET/models/archive.tar.gz ./
tar -xzf archive.tar.gz -C ./models/
```

### Sync Directories
```bash
# Local → GCS (upload new/changed files)
gcloud storage rsync -r ./outputs gs://BUCKET/outputs

# GCS → Local (download new/changed files)
gcloud storage rsync -r gs://BUCKET/checkpoints ./local-checkpoints

# Mirror: delete destination files not in source
gcloud storage rsync -r --delete-unmatched-destination-objects ./data gs://BUCKET/data

# Exclude patterns
gcloud storage rsync -r --exclude-name-pattern="*.tmp" ./logs gs://BUCKET/logs

# Dry run — see what would change
gcloud storage rsync -r --dry-run ./outputs gs://BUCKET/outputs
```

### Stream Data
```bash
cat data.txt | gcloud storage cp - gs://BUCKET/data.txt
gcloud storage cp gs://BUCKET/data.txt - | wc -l
```

### Bucket Size
```bash
gcloud storage du -sh gs://BUCKET/
gcloud storage ls -r -l gs://BUCKET/ | tail -1
```

### Environment Variables
```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
export CLOUDSDK_CORE_PROJECT=project-id
```
