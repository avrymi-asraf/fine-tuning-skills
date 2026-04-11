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

### Stream Data
```bash
cat data.txt | gcloud storage cp - gs://BUCKET/data.txt
gcloud storage cp gs://BUCKET/data.txt - | wc -l
```

### Compress on Upload
```bash
tar -czf - data/ | gcloud storage cp - gs://BUCKET/data.tar.gz
gcloud storage cp -Z file.json gs://BUCKET/    # -Z = gzip encoding
```

### Environment Variables
```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
export CLOUDSDK_CORE_PROJECT=project-id
```
