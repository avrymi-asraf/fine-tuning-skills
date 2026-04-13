---
name: cloud-storage-artifacts
description: Manage ML artifacts on Google Cloud Storage — create buckets, upload/download models and checkpoints, set lifecycle policies, sync directories, and clean up old experiments. Use when the user needs to store, retrieve, organize, or manage ML training outputs in GCS, or when they mention buckets, checkpoints, artifact storage, storage classes, or cleanup.
---

<cloud-storage-artifacts>
This skill covers managing ML training artifacts on Google Cloud Storage (GCS) — the storage layer in the GCP ML workflow.

**What's covered:**
- `<bucket-setup>` — Creating buckets with the default ML lifecycle policy
- `<artifact-organization>` — Directory hierarchy and naming conventions for experiments, checkpoints, models
- `<upload-and-download>` — Moving artifacts with `gcloud storage cp`, metadata tagging, compression
- `<lifecycle-and-tiering>` — Storage classes, lifecycle rules, automatic cost reduction
- `<sync-and-cleanup>` — Syncing with `gcloud storage rsync`, pruning old runs with `cleanup-old-runs.sh`
- `<cost-optimization>` — Region selection, compression, class strategy
- `<anti-patterns>` — Egress charges, early deletion fees, versioning bloat

**Scripts:** `scripts/setup-bucket.sh` (bucket creation + lifecycle), `scripts/cleanup-old-runs.sh` (prune old experiment directories)
**References:** `references/cli-cheat-sheet.md` (all gcloud storage commands, upload/download/sync patterns), `references/storage-classes.md` (class comparison + ML recommendations), `references/documentation-links.md`

**Approach:** For each operation, write out the full command with the user's actual variable names. Let the user run it, read the output together, and decide next steps based on what happened.

**Prerequisite:** `cloud-infrastructure-setup` skill (authenticated `gcloud` CLI with a project set).
</cloud-storage-artifacts>

<bucket-setup>
Use `scripts/setup-bucket.sh` to create a bucket with an ML lifecycle policy. Run without arguments to see usage.

```bash
./scripts/setup-bucket.sh my-project-ml-artifacts --location=us-central1
./scripts/setup-bucket.sh my-project-ml-artifacts --location=us-central1 --versioning --no-lifecycle
```

The script creates the bucket with uniform bucket-level access and applies a default ML lifecycle policy:

| Prefix | Rule | Rationale |
|--------|------|-----------|
| `checkpoints/temp/`, `experiments/temp/` | Delete after 7 days | Scratch data |
| `checkpoints/` | → NEARLINE after 30 days | Infrequent rollback |
| `experiments/` | → COLDLINE after 90 days | Archived runs |
| `logs/` | Delete after 365 days | Old telemetry |

Use `--no-lifecycle` to skip the policy and configure manually. To inspect or clear:
```bash
gcloud storage buckets describe gs://BUCKET --format="value(lifecycle_config)"
gcloud storage buckets update gs://BUCKET --clear-lifecycle
```

**Region matters:** Always create the bucket in the same region as your compute (e.g. `us-central1` for Vertex AI). Cross-region egress is billed; same-region is free.
</bucket-setup>

<artifact-organization>
Recommended directory structure inside the bucket:

```
gs://my-project-ml-artifacts/
├── datasets/
│   ├── raw/dataset-a/
│   └── processed/dataset-a/v1.0/
├── experiments/
│   └── 2024-01-15-llama-7b-lora/
│       ├── config.yaml
│       ├── checkpoints/
│       │   ├── checkpoint-1000.pt
│       │   └── checkpoint-final.pt
│       ├── metrics.json
│       └── logs/
├── models/
│   ├── llama-7b-v1.0/
│   └── llama-7b-v1.1-finetuned/
├── checkpoints/
│   └── temp/                    # Auto-deleted by lifecycle
└── logs/
    └── tensorboard/
```

**Naming conventions:**
- Experiments: `YYYY-MM-DD-descriptive-name`
- Checkpoints: `checkpoint-{step}.pt`
- Models: `model-name-v{version}` or `model-name-v{version}-qualifier`

The hierarchy aligns with the lifecycle policy — `checkpoints/temp/` gets cleaned automatically, `experiments/` transitions to cheaper storage.
</artifact-organization>

<upload-and-download>
## Upload

Upload artifacts with `gcloud storage cp`. Tag with git metadata so you can trace every artifact back to a commit:

```bash
# Upload a directory with git metadata
gcloud storage cp -r ./experiment-output/ gs://BUCKET/experiments/run-001/ \
  --custom-metadata=git-commit=$(git rev-parse --short HEAD) \
  --custom-metadata=git-branch=$(git rev-parse --abbrev-ref HEAD) \
  --custom-metadata=upload-time=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Upload a single model file
gcloud storage cp model.pt gs://BUCKET/models/

# Compress and upload (for large checkpoint dirs)
tar -czf - ./checkpoints/ | gcloud storage cp - gs://BUCKET/checkpoints/run-001.tar.gz

# Upload to a specific storage class
gcloud storage cp --storage-class=NEARLINE ./old-data gs://BUCKET/archive/
```

Run the command. Read the output — it shows each file transferred and the total size. If upload fails, check authentication (`gcloud auth list`) and bucket permissions.

## Download

```bash
# Download a model directory
gcloud storage cp -r gs://BUCKET/models/llama-7b/ ./models/llama-7b/

# Download a single file
gcloud storage cp gs://BUCKET/experiments/run-001/checkpoint-final.pt ./model.pt

# Download and verify checksum
gcloud storage cp gs://BUCKET/model.pt ./model.pt
sha256sum ./model.pt    # compare with the expected hash

# Download and extract an archive
gcloud storage cp gs://BUCKET/models/archive.tar.gz ./
tar -xzf archive.tar.gz -C ./models/
```

Full command reference in `references/cli-cheat-sheet.md`.
</upload-and-download>

<lifecycle-and-tiering>
GCS storage classes trade access cost for storage cost. Use the right class for each data stage:

| Class | Access Pattern | Min Duration | Best For |
|-------|---------------|--------------|----------|
| STANDARD | Frequent | None | Active training data, recent checkpoints |
| NEARLINE | < 1×/month | 30 days | Previous experiments, model registry |
| COLDLINE | < 1×/quarter | 90 days | Archived experiments, old logs |
| ARCHIVE | < 1×/year | 365 days | Compliance, final model backups |

**Early deletion fees** apply if you delete an object before its minimum duration expires. Don't put short-lived data in NEARLINE — use STANDARD and let lifecycle rules transition it.

Custom lifecycle policy example (create as JSON, apply with `gcloud`):
```json
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
        "condition": {"age": 14, "matchesPrefix": ["checkpoints/"]}
      }
    ]
  }
}
```
```bash
gcloud storage buckets update gs://BUCKET --lifecycle-file=policy.json
```

Full storage class details including cross-provider comparison: `references/storage-classes.md`.
</lifecycle-and-tiering>

<sync-and-cleanup>
## Sync

Use `gcloud storage rsync` directly — it handles incremental transfers efficiently:

```bash
# Local → GCS
gcloud storage rsync -r ./outputs gs://BUCKET/outputs

# GCS → Local
gcloud storage rsync -r gs://BUCKET/checkpoints ./local-checkpoints

# Mirror mode: delete destination files not in source
gcloud storage rsync -r --delete-unmatched-destination-objects ./data gs://BUCKET/data

# Exclude patterns
gcloud storage rsync -r --exclude-name-pattern="*.tmp" ./logs gs://BUCKET/logs

# Dry run first — see what would change
gcloud storage rsync -r --dry-run ./outputs gs://BUCKET/outputs
```

Read the output — it lists every file that would be copied or deleted. Always dry-run before using `--delete-unmatched-destination-objects`.

## Cleanup

Use `scripts/cleanup-old-runs.sh` to prune old experiment directories — this handles timestamp comparison and keep-last logic:

```bash
./scripts/cleanup-old-runs.sh gs://BUCKET/experiments --older-than=30d --dry-run
./scripts/cleanup-old-runs.sh gs://BUCKET/experiments --keep-last=5
./scripts/cleanup-old-runs.sh gs://BUCKET/checkpoints --older-than=7d --yes
```

Always use `--dry-run` first. The script lists directories, checks timestamps, and requires explicit `yes` confirmation before deletion.
</sync-and-cleanup>

<cost-optimization>
1. **Same-region storage** — bucket and compute in the same region. Cross-region egress costs ~$0.08–0.12/GB.
2. **Lifecycle policies** — let `setup-bucket.sh` default policy auto-transition old data to cheaper classes.
3. **Compress before upload** — `tar -czf - dir/ | gcloud storage cp - gs://BUCKET/archive.tar.gz`
4. **Clean up failed runs** — delete checkpoints from crashed experiments immediately; don't let them age into NEARLINE (where early deletion fees apply).
5. **Check bucket size** — `gcloud storage du -sh gs://BUCKET/`

**Cost reference:** STANDARD ~$0.020/GB/month, NEARLINE ~$0.010, COLDLINE ~$0.004, ARCHIVE ~$0.0012. Full tables in `references/storage-classes.md`.
</cost-optimization>

<anti-patterns>
- **Cross-region egress** — Downloading data to a different region costs money. Keep compute and storage co-located.
- **Early deletion fees** — Deleting NEARLINE objects before 30 days costs the prorated remainder. Use STANDARD for short-lived data.
- **Versioning bloat** — Enabling versioning without a cleanup rule causes unbounded growth. If versioning is on, add a lifecycle rule: `{"action":{"type":"Delete"},"condition":{"numNewerVersions":3}}`.
- **Listing huge directories** — `gcloud storage ls gs://BUCKET/` on 1M+ objects is slow. Always use a prefix: `gcloud storage ls gs://BUCKET/experiments/2024-01/`.
- **Hardcoded bucket names** — Pass bucket names as arguments or env vars. Never embed them in scripts.
</anti-patterns>

<cloud-storage-scripts>
| Script | Purpose |
|--------|---------|
| `setup-bucket.sh` | Create bucket with ML lifecycle policy, uniform access, optional versioning |
| `cleanup-old-runs.sh` | Delete old experiment directories by age or count, with dry-run and confirmation |

For upload, download, and sync — use `gcloud storage cp` and `gcloud storage rsync` directly. Full command patterns in `references/cli-cheat-sheet.md`.
</cloud-storage-scripts>

<cloud-storage-reference>
| File | Contents |
|------|----------|
| `references/cli-cheat-sheet.md` | All gcloud storage commands: buckets, objects, upload with metadata, download with verification, sync, compress, stream |
| `references/storage-classes.md` | Storage class comparison, ML workload recommendations, cost tables |
| `references/documentation-links.md` | Official GCS documentation and ML storage architecture links |
</cloud-storage-reference>

<examples>
**Scenario:** Set up artifact storage for a new fine-tuning project, run an experiment, then clean up.

**Step 1 — Create bucket:**
```bash
./scripts/setup-bucket.sh my-llama-training --location=us-central1
```
Run it. The output shows the bucket URL and confirms the lifecycle policy was applied.

**Step 2 — Upload training data with metadata:**
```bash
gcloud storage cp -r ./prepared-data/ gs://my-llama-training/datasets/processed/alpaca-v1/ \
  --custom-metadata=git-commit=$(git rev-parse --short HEAD)
```
Read the output — it lists each file transferred. Check the total count matches what you expect.

**Step 3 — After training, upload results:**
```bash
gcloud storage cp -r ./experiment-output/ gs://my-llama-training/experiments/2024-01-15-llama-lora/ \
  --custom-metadata=git-commit=$(git rev-parse --short HEAD) \
  --custom-metadata=upload-time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

**Step 4 — Download the model on another machine:**
```bash
gcloud storage cp -r gs://my-llama-training/experiments/2024-01-15-llama-lora/ ./local-run/
```

**Step 5 — Keep outputs in sync during training:**
```bash
gcloud storage rsync -r ./logs gs://my-llama-training/logs/tensorboard/
```

**Step 6 — Clean up old experiments after a month:**
```bash
./scripts/cleanup-old-runs.sh gs://my-llama-training/experiments --older-than=30d --dry-run
# Review output — it lists directories and their ages
./scripts/cleanup-old-runs.sh gs://my-llama-training/experiments --older-than=30d --yes
```

**Common mistake — wrong region causes egress charges:**
```bash
# Bad: bucket in us-east1, Vertex AI job in us-central1 → egress fees
# Good: match your compute region
./scripts/setup-bucket.sh my-bucket --location=us-central1
```
</examples>
