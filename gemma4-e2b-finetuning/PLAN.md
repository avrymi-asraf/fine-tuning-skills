# Gemma 4 E2B Fine-Tuning Plan (Cloud-First)

> Target: **Google Gemma 4 E2B** (Effective 2B, released April 2026)  
> Goal: Fine-tune with the **simplest possible tools**, running primarily on **Vertex AI** in the cloud.  
> Strategy: Containerized parameter-efficient fine-tuning (LoRA/QLoRA) submitted as Vertex AI custom jobs.

---

## 1. Executive Summary

This plan uses the **existing cloud skills** in the `fine-tuning-skills` repo to run Gemma 4 E2B fine-tuning on Google Cloud. Local execution remains available for prototyping, but the production path is:

1. **GCP infrastructure setup** (`cloud-infrastructure-setup`)
2. **Artifact storage** on GCS (`cloud-storage-artifacts`)
3. **GPU container build & push** (`container-engineering`)
4. **Dataset preparation & upload**
5. **Vertex AI custom job submission** (`cloud-job-orchestration`)
6. **Model export & download**

Gemma 4 E2B is small enough that a **single L4 or T4 GPU** is sufficient for LoRA fine-tuning, making this extremely cost-effective in the cloud.

---

## 2. Phase 0 — Cloud Infrastructure Setup

**Skill:** `cloud-infrastructure-setup`

### 2.1 Prerequisites
- GCP project with billing linked
- Required APIs enabled: `aiplatform`, `compute`, `storage`, `artifactregistry`, `cloudbuild`, `logging`, `monitoring`
- ADC + gcloud auth configured
- Vertex AI training GPU quota > 0 (defaults to 0 — request early)

### 2.2 Commands
```bash
# Authenticate
./cloud-infrastructure-setup/scripts/gcp_auth.sh login
./cloud-infrastructure-setup/scripts/gcp_auth.sh adc

# Check health before anything else
./cloud-infrastructure-setup/scripts/gcp_diagnose.sh full my-project

# Check GPU quota (critical — defaults to 0)
./cloud-infrastructure-setup/scripts/gcp_diagnose.sh quotas my-project us-central1
```

> ⚠️ **Never submit a GPU job without confirming quota first.** If `custom_model_training_nvidia_l4_gpus` or `custom_model_training_nvidia_t4_gpus` is 0, request an increase (2–3 business days).

### 2.3 Service Account Roles
Create a dedicated service account for training jobs and grant:
- `roles/aiplatform.user`
- `roles/storage.admin`
- `roles/artifactregistry.reader`
- `roles/logging.logWriter`
- `roles/monitoring.metricWriter`

---

## 3. Phase 1 — Artifact Storage on GCS

**Skill:** `cloud-storage-artifacts`

### 3.1 Create Bucket
Create the bucket in the **same region as training** (e.g., `us-central1`) to avoid egress charges:

```bash
./cloud-storage-artifacts/scripts/setup-bucket.sh my-project-gemma4-ft --location=us-central1
```

The script applies an ML lifecycle policy automatically (temp checkpoints delete after 7 days, experiments move to NEARLINE after 90 days).

### 3.2 Upload Dataset
```bash
gcloud storage cp -r ./data/formatted_dataset/ \
  gs://my-project-gemma4-ft/datasets/gemma4-e2b-v1/
```

### 3.3 Artifact Organization
Training outputs will land under:
```
gs://my-project-gemma4-ft/
├── datasets/
│   └── gemma4-e2b-v1/
├── experiments/
│   └── gemma4-e2b-lora-YYYY-MM-DD/
│       ├── checkpoints/
│       ├── config.yaml
│       └── logs/
└── models/
    └── gemma4-e2b-finetuned/
```

---

## 4. Phase 2 — Container Engineering

**Skill:** `container-engineering`

### 4.1 Dockerfile
Build a multi-stage GPU container using the `container-engineering` template. Key requirements:
- **Base:** `nvidia/cuda:12.4.1-runtime-ubuntu22.04` (runtime) + `nvidia/cuda:12.4.1-devel-ubuntu22.04` (builder)
- **Install:** `unsloth`, `trl`, `peft`, `datasets`, `accelerate`, `bitsandbytes`, `transformers`
- **Non-root user:** `USER trainer` (required by Vertex AI)
- **Entrypoint:** `python train.py` (or your training script)
- **AIP env vars:** Use `AIP_MODEL_DIR`, `AIP_CHECKPOINT_DIR`, `AIP_TENSORBOARD_LOG_DIR` for outputs

Use `scripts/Dockerfile.template.vertex` from `container-engineering` as the starting point.

### 4.2 Validate & Push
```bash
# Verify host CUDA compatibility
./container-engineering/scripts/validate-cuda.sh 12.4

# Build locally
DOCKER_BUILDKIT=1 docker build -t gemma4-train:v1.0.0 .

# Test GPU inside container
PROJECT_ID=my-project ./container-engineering/scripts/test-container-locally.sh gemma4-train:v1.0.0

# Push to Artifact Registry
PROJECT_ID=my-project REGION=us-central1 REPO_NAME=ml-containers IMAGE_NAME=gemma4-train \
  ./container-engineering/scripts/build-and-push.sh v1.0.0
```

Resulting URI: `us-central1-docker.pkg.dev/my-project/ml-containers/gemma4-train:v1.0.0`

---

## 5. Phase 3 — Dataset Preparation

**Skill:** `ml-training-pipeline` (for data format guidance)

### 5.1 Local Prep
Use `data/prepare_dataset.py` to:
- Load a HuggingFace dataset (or local JSONL)
- Apply the Gemma chat template
- Filter by `max_seq_length`
- Save to disk

```bash
python data/prepare_dataset.py \
  --dataset_name yahma/alpaca-cleaned \
  --max_samples 500 \
  --output_path data/formatted_dataset
```

### 5.2 Upload to GCS
```bash
gcloud storage cp -r ./data/formatted_dataset/ \
  gs://my-project-gemma4-ft/datasets/gemma4-e2b-v1/
```

---

## 6. Phase 4 — Cloud Training (Vertex AI)

**Skill:** `cloud-job-orchestration`

### 6.1 Cost Estimation
Before submitting, estimate cost:

```bash
./cloud-job-orchestration/scripts/cost-estimate.py \
  --machine-type g2-standard-8 --hours 2 --compare
```

For Gemma 4 E2B, a **single L4 (`g2-standard-8`)** or **single T4 (`n1-standard-8`)** is sufficient.

### 6.2 Job Config YAML
Create `configs/vertex_job.yaml` for the custom job:

```yaml
workerPoolSpecs:
  - machineSpec:
      machineType: g2-standard-8
      acceleratorType: NVIDIA_L4
      acceleratorCount: 1
    replicaCount: 1
    containerSpec:
      imageUri: us-central1-docker.pkg.dev/my-project/ml-containers/gemma4-train:v1.0.0
      command:
        - python
        - train_unsloth.py
      args:
        - --config=configs/unsloth_lora.yaml
        - --dataset_path=/gcs/datasets/gemma4-e2b-v1
        - --output_dir=/gcs/output
      env:
        - name: GCS_BUCKET
          value: gs://my-project-gemma4-ft
        - name: HF_TOKEN
          value: "$(HF_TOKEN)"  # Inject via Secret Manager in production
      # Mount GCS as a volume (optional, or read via FUSE)
```

> **Simpler alternative:** Have the container download data from GCS at startup, or use `gcsfuse` mounting. For small datasets (<1GB), downloading at startup is simplest.

### 6.3 Submit Job
```bash
# CPU smoke test first (no GPU quota needed)
uv run ./cloud-job-orchestration/scripts/submit-training-job.py \
  --config configs/vertex_job.yaml \
  --machine-type n1-standard-4 --accelerator-count 0

# Submit GPU job
uv run ./cloud-job-orchestration/scripts/submit-training-job.py \
  --config configs/vertex_job.yaml \
  --use-spot
```

### 6.4 Monitor
```bash
# Stream logs
./cloud-job-orchestration/scripts/monitor-job.sh $(cat .last_job_id) us-central1

# Or cancel if needed
gcloud ai custom-jobs cancel $(cat .last_job_id) --region=us-central1
```

### 6.5 Spot VMs & Checkpointing
Use **Spot VMs** for 60–91% cost savings. The training script **must** checkpoint regularly:

```python
# Inside train_hf_peft.py
training_args = TrainingArguments(
    output_dir=os.environ.get("AIP_MODEL_DIR", "/output"),
    save_strategy="steps",
    save_steps=100,
    save_total_limit=3,
    resume_from_checkpoint=last_checkpoint,
)
```

If preempted, use the retry handler:
```bash
./cloud-job-orchestration/scripts/handle-preemption.sh \
  --config configs/vertex_job.yaml --max-retries 3 --region us-central1
```

---

## 7. Phase 5 — Local Development (Fallback)

For rapid iteration without cloud costs, run locally using the same scripts:

```bash
# Local training (HF PEFT + QLoRA)
uv run python train_hf_peft.py --dataset_path data/formatted_dataset

# Local inference
uv run python inference.py --model_path outputs/hf-gemma4-e2b/lora_adapter
```

Local requirements:
- GPU with 8GB+ VRAM (L4, T4, RTX 3060/4060)
- CUDA 12.4 compatible driver
- uv installed (`curl -LsSf https://astral.sh/uv/install.sh | sh`)

---

## 8. Phase 6 — Export & Download

### 8.1 Cloud Export
After training completes in Vertex AI, results are in `gs://my-project-gemma4-ft/experiments/JOB_ID/`.

Download artifacts:
```bash
JOB_ID=$(cat .last_job_id)
gcloud storage cp -r \
  gs://my-project-gemma4-ft/experiments/$JOB_ID/ \
  ./results/gemma4-e2b-cloud/
```

### 8.2 Model Export Formats
Run `export.py` locally or inside the cloud container to produce:
- **LoRA adapter** — for resume/share
- **Merged 16-bit** — standard HF inference
- **GGUF (Q4_K_M, Q8_0)** — for llama.cpp / Ollama

```bash
python export.py \
  --mode all \
  --model_path google/gemma-4-2b-it \
  --adapter_path ./results/gemma4-e2b-cloud/lora_adapter \
  --output_dir ./exports
```

---

## 9. Recommended File Structure

```
gemma4-e2b-finetuning/
├── PLAN.md                       # This document
├── pyproject.toml                # uv project configuration
├── uv.lock                       # Locked dependencies
├── Dockerfile                    # Multi-stage GPU container
├── requirements.txt              # (legacy, see pyproject.toml)
├── configs/
│   ├── hf_qlora.yaml             # HF PEFT hyperparameters
│   └── vertex_job.yaml           # Vertex AI job config
├── data/
│   └── prepare_dataset.py        # Load + format + upload dataset
├── train_hf_peft.py              # Primary training script (HF PEFT)
├── inference.py                  # Quick local inference
└── export.py                     # Merge adapters / export GGUF
```

---

## 10. Hyperparameter Cheatsheet

| Param | HF PEFT | Notes |
|-------|---------|-------|
| rank (r) | 16 | Start here; 8 for tiny VRAM, 32 for complex tasks |
| lora_alpha | 32 | Standard 2:1 ratio |
| lora_dropout | 0.05 | Regularization |
| max_seq_length | 2048 | E2B handles 8K; 2048 is safe |
| batch_size | 2 | Reduce to 1 if OOM |
| grad_accum | 4 | Effective batch = 8 |
| lr | 2e-4 | Standard for LoRA on small models |
| warmup_steps | 10 | Short for small datasets |
| max_steps | 60–500 | Scale with dataset size |

---

## 11. Cloud Execution Checklist

- [ ] Run `gcp_diagnose.sh full` and confirm all green
- [ ] Confirm Vertex AI GPU quota > 0 in target region
- [ ] Create GCS bucket in same region with `setup-bucket.sh`
- [ ] Prepare dataset locally and upload to GCS
- [ ] Build Dockerfile from `container-engineering` template
- [ ] Validate container locally with `test-container-locally.sh`
- [ ] Push image with `build-and-push.sh`
- [ ] Create `configs/vertex_job.yaml` with image URI and env vars
- [ ] Run cost estimate with `cost-estimate.py`
- [ ] Submit CPU smoke test first
- [ ] Submit GPU job (prefer Spot for cost savings)
- [ ] Monitor with `monitor-job.sh`
- [ ] Download results from GCS
- [ ] Run `export.py` to generate deployable formats

---

## 12. Skills Used

| Skill | Purpose |
|-------|---------|
| `cloud-infrastructure-setup` | GCP auth, project, APIs, IAM, quota checks |
| `cloud-storage-artifacts` | GCS bucket, dataset upload, result download |
| `container-engineering` | Multi-stage GPU Docker build, push to Artifact Registry |
| `cloud-job-orchestration` | Vertex AI custom job submission, monitoring, Spot VMs |
| `ml-training-pipeline` | Dataset formatting, LoRA/QLoRA patterns, training scripts |
