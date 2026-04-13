---
name: cloud-job-orchestration
description: Submit, monitor, and manage Vertex AI custom training jobs on GCP. Covers job configuration, GPU machine selection, Spot VMs with preemption handling, cost estimation, log streaming, and TensorBoard integration. Use when the user needs to run, schedule, monitor, cancel, or debug ML training jobs on Vertex AI — or when choosing GPU machine types and estimating costs.
---

<cloud-job-orchestration>
This skill covers the full lifecycle of Vertex AI custom training jobs — from choosing GPU hardware and estimating costs through job submission, monitoring, preemption recovery, and artifact retrieval.

**What's covered:**
- `<job-submission>` — Two ways to submit jobs: Python SDK and gcloud CLI, with config files
- `<gpu-machine-selection>` — Choosing the right machine type and accelerator for the workload
- `<spot-and-preemption>` — Spot VMs for cost savings, preemption signals, checkpointing strategy
- `<job-monitoring>` — Status polling, log streaming, cancellation, TensorBoard integration
- `<cost-estimation>` — Estimating job cost before submission, budget awareness
- `<environment-and-secrets>` — Vertex AI automatic env vars, Secret Manager integration
- `<common-pitfalls>` — OOM, queued jobs, container startup failures, data bottlenecks
- `<examples>` — End-to-end workflow from cost estimate to result download

**Scripts:** `scripts/submit-training-job.py`, `scripts/monitor-job.sh`, `scripts/handle-preemption.sh`, `scripts/cost-estimate.py`, `scripts/example-job-config.yaml`
**References:** `references/gpu-machine-types.md`, `references/command-cheat-sheet.md`, `references/documentation-links.md`

**Approach:** Write the full command with actual variable names, let the user run it, read the output together. For simple operations like cancelling a job — use `gcloud` directly, no script needed.

**Prerequisites:** `cloud-infrastructure-setup` (GCP auth, project, APIs, IAM configured). Container image already pushed to Artifact Registry or GCR.
</cloud-job-orchestration>

<job-submission>
**Before any GPU job — check quota first.** Vertex AI training uses separate quota metrics from Compute Engine (e.g. `custom_model_training_nvidia_t4_gpus`). A zero quota means every GPU submit will fail with `RESOURCE_EXHAUSTED`:
```bash
# Check Vertex AI training + compute GPU quotas
./cloud-infrastructure-setup/scripts/gcp_diagnose.sh quotas PROJECT_ID us-central1
```
If GPU quota is 0, request an increase first (2–3 business days). Meanwhile, validate the container with a **CPU-only smoke test** (see `<examples>`).

There are two submission approaches. Use whichever fits the workflow.

**Python SDK (recommended)** — use `scripts/submit-training-job.py` for config files, automatic `.last_job_id` output, and dry-run support:
```bash
# From a YAML config
uv run scripts/submit-training-job.py --config job_config.yaml

# Inline arguments
uv run scripts/submit-training-job.py \
  --container-uri gcr.io/PROJECT/training:v1 \
  --machine-type a2-highgpu-1g \
  --accelerator-type NVIDIA_TESLA_A100 --accelerator-count 1 \
  --base-output-dir gs://bucket/outputs \
  --use-spot --dry-run
```

The SDK approach (`CustomJob`) takes `worker_pool_specs` — each spec defines machine type, container image, env vars, and disk config. See `scripts/example-job-config.yaml` for a complete config template.

**gcloud CLI** — faster for one-off jobs, but does **not** write `.last_job_id`:
```bash
gcloud ai custom-jobs create \
  --region=us-central1 \
  --display-name=training-job \
  --config=job_config.yaml
```
Read the output — it prints the job resource name. Extract the job ID for monitoring:
```bash
JOB_ID=$(gcloud ai custom-jobs list --region=us-central1 --sort-by=~createTime --limit=1 --format='value(name.split("/").slice(-1))')
```

The YAML config for gcloud uses camelCase keys (`machineType`, `acceleratorType`, `containerSpec`). See `references/command-cheat-sheet.md` for config file format.

Always call `aiplatform.init(project=PROJECT, location=REGION)` before creating jobs via SDK.
</job-submission>

<gpu-machine-selection>
Full tables in `references/gpu-machine-types.md`. Quick decision guide:

| Workload | Machine Type | GPU | VRAM |
|----------|-------------|-----|------|
| Fine-tune ≤7B model | `g2-standard-8` | 1× L4 | 24 GB |
| Fine-tune 7B–13B | `a2-highgpu-1g` | 1× A100 40GB | 40 GB |
| Fine-tune 13B–70B | `a2-ultragpu-1g` | 1× A100 80GB | 80 GB |
| Fine-tune >70B (multi-GPU) | `a3-highgpu-8g` | 8× H100 | 640 GB |
| Inference / prototyping | `g2-standard-4` | 1× L4 | 24 GB |
| Budget experiments | `n1-standard-8` + T4 | 1× T4 | 16 GB |

**Accelerator type strings** for the SDK: `NVIDIA_TESLA_A100`, `NVIDIA_A100_80GB`, `NVIDIA_H100_80GB`, `NVIDIA_L4`, `NVIDIA_TESLA_T4`, `NVIDIA_TESLA_V100`.

For A3/A2/G2 machines, the GPU is fixed to the machine type — don't specify `accelerator_type` separately. For N1 machines, attach GPUs explicitly with `accelerator_type` + `accelerator_count`.

**Region availability** varies. Check with:
```bash
gcloud compute accelerator-types list --filter="zone:us-central1"
```
</gpu-machine-selection>

<spot-and-preemption>
Spot VMs cost 60–91% less but can be preempted at any time. GCP sends `SIGTERM` 30 seconds before termination.

**Enable Spot in SDK:**
```python
job = aiplatform.CustomJob(
    display_name="training-job",
    worker_pool_specs=[...],
    scheduling={"strategy": "SPOT", "max_wait_duration": "3600s"},
)
```

**Preemption recovery** — use `scripts/handle-preemption.sh` to auto-retry preempted jobs:
```bash
./scripts/handle-preemption.sh --config job_config.yaml --max-retries 5 --region us-central1
```

**Checkpointing is mandatory with Spot.** Vertex AI sets `AIP_CHECKPOINT_DIR` automatically. In HuggingFace Trainer:
```python
training_args = TrainingArguments(
    output_dir=os.environ.get("AIP_MODEL_DIR", "/output"),
    save_strategy="steps",
    save_steps=100,
    save_total_limit=3,
    resume_from_checkpoint=last_checkpoint,  # auto-resume on retry
)
```

Handle `SIGTERM` with a callback that sets `control.should_save = True` and `control.should_training_stop = True`. The training code in the container is responsible for saving state within the 30-second window.
</spot-and-preemption>

<job-monitoring>
**Stream logs** (blocks until job ends):
```bash
gcloud ai custom-jobs stream-logs JOB_ID --region=us-central1
```

**Use `scripts/monitor-job.sh`** for status polling with elapsed time, status change alerts, and auto-cleanup:
```bash
./scripts/monitor-job.sh JOB_ID us-central1
./scripts/monitor-job.sh $(cat .last_job_id)    # only works after submit-training-job.py
```

If you submitted via gcloud CLI (no `.last_job_id`), get the job ID first:
```bash
JOB_ID=$(gcloud ai custom-jobs list --region=us-central1 --sort-by=~createTime --limit=1 --format='value(name.split("/").slice(-1))')
```

**Job states:** `PENDING` → `RUNNING` → `SUCCEEDED` / `FAILED` / `CANCELLED` / `PREEMPTED`. The `PREEMPTING` state means the 30-second shutdown window is active.

**Cancel a job** — use `gcloud` directly:
```bash
gcloud ai custom-jobs cancel JOB_ID --region=us-central1
```
Read the output. Then check the state: `gcloud ai custom-jobs describe JOB_ID --region=us-central1 --format='value(state)'`. If already in a terminal state (`SUCCEEDED`, `FAILED`, `CANCELLED`), no action is needed.

**TensorBoard** — create a TensorBoard instance, then pass its resource name when creating the job:
```python
tensorboard = aiplatform.TensorBoard.create(display_name="training-logs")
job = aiplatform.CustomContainerTrainingJob(
    display_name="training-job",
    container_uri="gcr.io/PROJECT/training:v1",
    tensorboard=tensorboard.resource_name,
)
```

The container writes to `AIP_TENSORBOARD_LOG_DIR` and Vertex AI syncs it automatically.
</job-monitoring>

<cost-estimation>
**Use `scripts/cost-estimate.py`** before every job:
```bash
uv run scripts/cost-estimate.py --machine-type a2-highgpu-1g --hours 24 --compare
uv run scripts/cost-estimate.py --machine-type a2-highgpu-1g --hours 24 --use-spot
uv run scripts/cost-estimate.py --list-machines    # show all options with pricing
```

Quick reference (GPU cost only, approximate):

| GPU | On-Demand/hr | Spot/hr |
|-----|-------------|---------|
| H100 80GB | ~$4.50 | ~$1.35 |
| A100 40GB | ~$2.48 | ~$0.74 |
| A100 80GB | ~$3.67 | ~$1.10 |
| L4 | ~$0.80 | ~$0.24 |
| T4 | ~$0.35 | ~$0.11 |

Total job cost = (machine + GPU) × hours. Actual pricing changes — always verify with the [GCP pricing page](https://cloud.google.com/compute/gpus-pricing).
</cost-estimation>

<environment-and-secrets>
Vertex AI injects these env vars into the container automatically:

| Variable | Contents |
|----------|----------|
| `AIP_MODEL_DIR` | GCS path for model artifacts |
| `AIP_CHECKPOINT_DIR` | GCS path for checkpoints |
| `AIP_TENSORBOARD_LOG_DIR` | GCS path for TensorBoard logs |
| `CLOUD_ML_JOB_ID` | Current job ID |
| `CLOUD_ML_PROJECT_ID` | Project ID |

**Never hardcode secrets in the container or config.** Use Secret Manager:
```python
from google.cloud import secretmanager
client = secretmanager.SecretManagerServiceClient()
name = f"projects/{os.environ['CLOUD_ML_PROJECT_ID']}/secrets/hf-token/versions/latest"
hf_token = client.access_secret_version(request={"name": name}).payload.data.decode("UTF-8")
```

Pass custom env vars via the config's `env` field — they're visible in the job spec. Tokens and keys must go through Secret Manager.
</environment-and-secrets>

<common-pitfalls>
| Problem | Symptom | Fix |
|---------|---------|-----|
| GPU OOM | `CUDA out of memory` | Lower `per_device_train_batch_size`, increase `gradient_accumulation_steps`, enable `gradient_checkpointing` |
| Vertex AI training GPU quota | `RESOURCE_EXHAUSTED` for `custom_model_training_nvidia_*_gpus` | Check with `gcp_diagnose.sh quotas`. Request increase in Console → IAM → Quotas. Use CPU smoke test while waiting. |
| Job stuck queued | `PENDING` for hours | Try spot (better availability), different region, request quota increase |
| Container fails immediately | `FAILED` right after `RUNNING` | Test locally: `docker run --gpus all IMAGE python -c "import torch; print(torch.cuda.is_available())"` |
| Slow training / GPU underused | Low GPU utilization | Increase `dataloader_num_workers`, use `pin_memory=True`, pre-process data |
| No `.last_job_id` for monitoring | `cat .last_job_id` fails | Only `submit-training-job.py` writes this file. Extract with: `gcloud ai custom-jobs list --sort-by=~createTime --limit=1 --format='value(name.split("/").slice(-1))'` |
</common-pitfalls>

<cloud-job-orchestration-scripts>
All scripts are self-documenting — run without arguments for usage.

| Script | Purpose |
|--------|---------|
| `submit-training-job.py` | Submit Vertex AI custom job from YAML config or CLI args. Saves job ID for monitoring. |
| `monitor-job.sh` | Poll job status, stream logs, show elapsed time. Handles all terminal states. |
| `handle-preemption.sh` | Auto-retry preempted spot jobs with configurable max retries and delay. |
| `cost-estimate.py` | Estimate cost by machine type, hours, and spot/on-demand. Supports `--compare` and `--list-machines`. |
| `example-job-config.yaml` | Template YAML config with all common fields filled in. |

For cancelling jobs — use `gcloud ai custom-jobs cancel JOB_ID --region=REGION` directly. Full CLI reference in `references/command-cheat-sheet.md`.
</cloud-job-orchestration-scripts>

<cloud-job-orchestration-reference>
| File | Contents |
|------|----------|
| `references/gpu-machine-types.md` | Full GPU machine type tables for A3, A2, G2, G4, N1 series and TPUs. Selection guide by use case and budget. |
| `references/command-cheat-sheet.md` | gcloud CLI and Python SDK quick reference: job CRUD, config file format, GCS operations, troubleshooting commands. |
| `references/documentation-links.md` | Official Vertex AI docs, SDK references, pricing pages, spot VM guides, TensorBoard docs. |
</cloud-job-orchestration-reference>

<examples>
**End-to-end: Fine-tune a 7B model on Vertex AI with Spot VMs.**

**1. Check quota** — do this before any GPU submission:
```bash
./cloud-infrastructure-setup/scripts/gcp_diagnose.sh quotas my-project us-central1
```
Read the output — look for `custom_model_training_nvidia_*` metrics. If limit is 0, request increase first.

**2. Estimate cost:**
```bash
uv run scripts/cost-estimate.py --machine-type a2-highgpu-1g --hours 12 --compare
```

**3. Prepare config** — copy and edit the template:
```bash
cp scripts/example-job-config.yaml my-job.yaml
# Edit: set container_uri, model name, GCS paths, env vars
```

**4. CPU smoke test** — validate container without GPU quota:
```bash
uv run scripts/submit-training-job.py --config my-job.yaml \
  --machine-type n1-standard-4 --accelerator-count 0 --dry-run
# Review config, then submit (remove --dry-run) to verify the container starts
```

**5. Submit GPU job** (only after quota confirmed):
```bash
uv run scripts/submit-training-job.py --config my-job.yaml --use-spot
```

**6. Monitor:**
```bash
./scripts/monitor-job.sh $(cat .last_job_id)
```

**7. If preempted**, use the retry handler:
```bash
./scripts/handle-preemption.sh --config my-job.yaml --max-retries 5
```

**8. Download results:**
```bash
gcloud storage cp -r gs://bucket/outputs/JOB_ID ./results/
```

**Common mistake — submitting GPU jobs without checking quota:** Vertex AI training GPU quotas (`custom_model_training_nvidia_*_gpus`) default to 0. Check first, request increase, validate with CPU smoke test, then submit after quota is approved.
</examples>
