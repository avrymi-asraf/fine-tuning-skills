---
name: cloud-storage-artifacts
description: Manage ML artifacts on Google Cloud Storage — create buckets, upload/download models and checkpoints, set lifecycle policies, sync directories, and clean up old experiments. Use when the user needs to store, retrieve, organize, or manage ML training outputs in GCS, or when they mention buckets, checkpoints, artifact storage, storage classes, or cleanup.
---

<cloud-storage-artifacts>
This skill covers managing ML training artifacts on Google Cloud Storage (GCS) — the storage layer in the GCP ML workflow.

**What's covered:**
- `<bucket-setup>` — Creating buckets with `setup-bucket.sh` and the default ML lifecycle policy
- `<artifact-organization>` — Directory hierarchy and naming conventions for experiments, checkpoints, models
- `<upload-and-download>` — Moving artifacts with `upload-training-artifacts.sh` and `download-model.sh`
- `<lifecycle-and-tiering>` — Storage classes, lifecycle rules, automatic cost reduction
- `<sync-and-cleanup>` — Keeping local/cloud in sync with `sync-directory.sh`, pruning old runs with `cleanup-old-runs.sh`
- `<cost-optimization>` — Region selection, compression, class strategy
- `<anti-patterns>` — Egress charges, early deletion fees, versioning bloat

**Scripts:** `scripts/setup-bucket.sh`, `scripts/upload-training-artifacts.sh`, `scripts/download-model.sh`, `scripts/cleanup-old-runs.sh`, `scripts/sync-directory.sh`
**References:** `references/cli-cheat-sheet.md` (gcloud storage commands), `references/storage-classes.md` (class comparison + ML recommendations), `references/documentation-links.md`

**Prerequisite:** `cloud-infrastructure-setup` skill (authenticated `gcloud` CLI with a project set).
</cloud-storage-artifacts>

<bucket-setup>
Use `scripts/setup-bucket.sh` to create a bucket. Run without arguments to see usage.

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

Use `scripts/upload-training-artifacts.sh`. Automatically tags objects with git commit, branch, timestamp, and hostname as GCS custom metadata.

```bash
./scripts/upload-training-artifacts.sh ./outputs gs://bucket/experiments/run-001
./scripts/upload-training-artifacts.sh --compress ./model gs://bucket/models/v1.0.tar.gz
./scripts/upload-training-artifacts.sh --storage-class=NEARLINE ./old-data gs://bucket/archive/
```

For manual single-file uploads:
```bash
gcloud storage cp model.pt gs://bucket/models/
gcloud storage cp -r ./experiment-dir/ gs://bucket/experiments/run-001/
```

## Download

Use `scripts/download-model.sh`. Supports checksum verification and archive extraction.

```bash
./scripts/download-model.sh gs://bucket/models/llama-7b ./models/llama-7b
./scripts/download-model.sh --verify --checksum=abc123def456 gs://bucket/model.pt ./model.pt
./scripts/download-model.sh --extract gs://bucket/models/archive.tar.gz ./models/
```

For quick manual downloads:
```bash
gcloud storage cp gs://bucket/models/model.pt ./
gcloud storage cp -r gs://bucket/experiments/run-001/ ./local-run/
```
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

Use `scripts/sync-directory.sh` — a thin wrapper around `gcloud storage rsync`:

```bash
./scripts/sync-directory.sh ./outputs gs://bucket/outputs
./scripts/sync-directory.sh gs://bucket/checkpoints ./local-checkpoints
./scripts/sync-directory.sh --delete ./data gs://bucket/data       # mirror: delete extras at dest
./scripts/sync-directory.sh --exclude="*.tmp" ./logs gs://bucket/logs
```

## Cleanup

Use `scripts/cleanup-old-runs.sh` to prune old experiment directories:

```bash
./scripts/cleanup-old-runs.sh gs://bucket/experiments --older-than=30d --dry-run
./scripts/cleanup-old-runs.sh gs://bucket/experiments --keep-last=5
./scripts/cleanup-old-runs.sh gs://bucket/checkpoints --older-than=7d --yes
```

Always use `--dry-run` first. The script lists directories, checks timestamps, and requires explicit `yes` confirmation before deletion.
</sync-and-cleanup>

<cost-optimization>
1. **Same-region storage** — bucket and compute in the same region. Cross-region egress costs ~$0.08–0.12/GB.
2. **Lifecycle policies** — let `setup-bucket.sh` default policy auto-transition old data to cheaper classes.
3. **Compress before upload** — use `--compress` flag on `upload-training-artifacts.sh`, or manually: `tar -czf - dir/ | gcloud storage cp - gs://bucket/archive.tar.gz`
4. **Clean up failed runs** — delete checkpoints from crashed experiments immediately; don't let them age into NEARLINE (where early deletion fees apply).
5. **Check bucket size** — `gcloud storage du -sh gs://bucket/` or `gcloud storage ls -r -l gs://bucket/ | tail -1`

**Cost reference:** STANDARD ~$0.020/GB/month, NEARLINE ~$0.010, COLDLINE ~$0.004, ARCHIVE ~$0.0012. Full tables in `references/storage-classes.md`.
</cost-optimization>

<anti-patterns>
- **Cross-region egress** — Downloading data to a different region costs money. Keep compute and storage co-located.
- **Early deletion fees** — Deleting NEARLINE objects before 30 days costs the prorated remainder. Use STANDARD for short-lived data.
- **Versioning bloat** — Enabling versioning without a cleanup rule causes unbounded growth. If versioning is on, add a lifecycle rule: `{"action":{"type":"Delete"},"condition":{"numNewerVersions":3}}`.
- **Listing huge directories** — `gcloud storage ls gs://bucket/` on 1M+ objects is slow. Always use a prefix: `gcloud storage ls gs://bucket/experiments/2024-01/`.
- **Silent upload failures** — Script continues after `gcloud storage cp` fails. All scripts use `set -euo pipefail` to prevent this.
- **Hardcoded bucket names** — Pass bucket names as arguments or env vars. Never embed them in scripts.
</anti-patterns>

<cloud-storage-scripts>
All scripts show usage when run without arguments.

| Script | Purpose |
|--------|---------|
| `setup-bucket.sh` | Create bucket with ML lifecycle policy |
| `upload-training-artifacts.sh` | Upload with metadata tagging and optional compression |
| `download-model.sh` | Download with optional checksum verification and extraction |
| `cleanup-old-runs.sh` | Delete old experiment directories by age or count |
| `sync-directory.sh` | Sync local ↔ GCS directories |
</cloud-storage-scripts>

<cloud-storage-reference>
| File | Contents |
|------|----------|
| `references/cli-cheat-sheet.md` | Quick-reference gcloud storage and gsutil commands |
| `references/storage-classes.md` | Storage class comparison, ML workload recommendations, cost tables |
| `references/documentation-links.md` | Official GCS documentation and ML storage architecture links |
</cloud-storage-reference>

<examples>
**Scenario:** Set up artifact storage for a new fine-tuning project, run an experiment, then clean up.

**Step 1 — Create bucket:**
```bash
./scripts/setup-bucket.sh my-llama-training --location=us-central1
# Creates gs://my-llama-training with default lifecycle policy
```

**Step 2 — Upload training data:**
```bash
./scripts/upload-training-artifacts.sh ./prepared-data gs://my-llama-training/datasets/processed/alpaca-v1/
```

**Step 3 — After training, upload results:**
```bash
./scripts/upload-training-artifacts.sh ./experiment-output gs://my-llama-training/experiments/2024-01-15-llama-lora/
# Metadata auto-tagged: git commit, branch, timestamp
```

**Step 4 — Download the model on another machine:**
```bash
./scripts/download-model.sh gs://my-llama-training/experiments/2024-01-15-llama-lora/checkpoint-final.pt ./model.pt
```

**Step 5 — Keep outputs in sync during training:**
```bash
./scripts/sync-directory.sh ./logs gs://my-llama-training/logs/tensorboard/
```

**Step 6 — Clean up old experiments after a month:**
```bash
./scripts/cleanup-old-runs.sh gs://my-llama-training/experiments --older-than=30d --dry-run
# Review output, then:
./scripts/cleanup-old-runs.sh gs://my-llama-training/experiments --older-than=30d --yes
```

**Common mistake — wrong region causes egress charges:**
```bash
# Bad: bucket in us-east1, Vertex AI job in us-central1 → egress fees
./scripts/setup-bucket.sh my-bucket --location=us-east1

# Good: match your compute region
./scripts/setup-bucket.sh my-bucket --location=us-central1
```
</examples>
