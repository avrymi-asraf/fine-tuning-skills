# Qwen 3.5 2B Fine-Tuning Plan (Local-First)

> Target: **Qwen 3.5 2B** (2B parameter causal LM, released 2025)  
> Goal: Fine-tune locally with the **simplest possible tools**, using LoRA/QLoRA.  
> Strategy: Local training as the default path; cloud (Vertex AI) as an optional extension.

---

## 1. Executive Summary

This project fine-tunes **Qwen/Qwen3.5-2B** using standard HuggingFace tools (TRL, PEFT, Transformers) with QLoRA for memory efficiency. The primary workflow runs **on your local machine** (or a local GPU server). Cloud deployment via Vertex AI is supported but optional.

**Why Qwen 3.5 2B?**
- 2B parameters — fits easily on consumer GPUs (8GB+ VRAM) with QLoRA
- 262K native context length (we use 4096 for training to keep it fast)
- ChatML format built into tokenizer (`<|im_start|>`, `<|im_end|>`)
- Strong performance for its size

**Architecture details:**
- Hidden size: 2048
- Num layers: 24
- Intermediate size: 6144
- Context length: 262,144 tokens natively
- Architecture: 6 × (3 × (Gated DeltaNet → FFN) → 1 × (Gated Attention → FFN))
- Default mode: non-thinking

---

## 2. Phase 0 — Local Environment Setup

### 2.1 Prerequisites
- Python 3.11+
- CUDA 12.4 compatible GPU (8GB+ VRAM for QLoRA)
- `uv` installed: `curl -LsSf https://astral.sh/uv/install.sh | sh`

### 2.2 Install Dependencies
```bash
uv sync
```

This installs PyTorch 2.6.0 (CUDA 12.4), transformers, trl, peft, bitsandbytes, and all other dependencies.

### 2.3 Verify GPU
```bash
uv run python -c "import torch; print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0))"
```

---

## 3. Phase 1 — Dataset Preparation

### 3.1 Prepare Dataset Locally
```bash
uv run python data/prepare_dataset.py \
  --dataset_name yahma/alpaca-cleaned \
  --tokenizer_name Qwen/Qwen3.5-2B \
  --max_seq_length 4096 \
  --max_samples 500 \
  --output_path data/formatted_dataset
```

This:
- Loads the dataset from HuggingFace
- Applies Qwen's ChatML chat template via `apply_chat_template`
- Filters examples exceeding `max_seq_length`
- Saves formatted dataset to disk

### 3.2 Use Your Own Dataset
If you have a local JSONL file with `messages` or `conversations` fields:
```bash
uv run python data/prepare_dataset.py \
  --dataset_name json \
  --dataset_config data/my_dataset.jsonl \
  --tokenizer_name Qwen/Qwen3.5-2B \
  --output_path data/formatted_dataset
```

---

## 4. Phase 2 — Local Training

### 4.1 Quick Start
```bash
uv run python train_hf_peft.py --dataset_path data/formatted_dataset
```

Training outputs go to `outputs/hf-qwen3.5-2b/` by default.

### 4.2 Custom Config
Edit `configs/hf_qlora.yaml` to adjust hyperparameters:
```yaml
model_name: "Qwen/Qwen3.5-2B"
max_seq_length: 4096
lora_r: 16
lora_alpha: 32
learning_rate: 2.0e-4
max_steps: 60
```

### 4.3 Resume from Checkpoint
If training is interrupted, it automatically resumes from the latest checkpoint in the output directory.

---

## 5. Phase 3 — Local Inference

### 5.1 Run Inference
```bash
uv run python inference.py \
  --model_path outputs/hf-qwen3.5-2b/lora_adapter \
  --adapter_path outputs/hf-qwen3.5-2b/lora_adapter
```

Or load the base model without adapter:
```bash
uv run python inference.py --model_path Qwen/Qwen3.5-2B
```

### 5.2 Interactive Mode
The script starts an interactive chat session. Type `quit` or `exit` to stop.

---

## 6. Phase 4 — Export

### 6.1 Export LoRA Adapter
```bash
uv run python export.py \
  --mode adapter \
  --model_path Qwen/Qwen3.5-2B \
  --adapter_path outputs/hf-qwen3.5-2b/lora_adapter \
  --output_dir exports
```

### 6.2 Merge Adapter to 16-bit Model
```bash
uv run python export.py \
  --mode merge \
  --model_path Qwen/Qwen3.5-2B \
  --adapter_path outputs/hf-qwen3.5-2b/lora_adapter \
  --output_dir exports
```

### 6.3 Export to GGUF (for llama.cpp / Ollama)
```bash
uv run python export.py \
  --mode gguf \
  --adapter_path outputs/hf-qwen3.5-2b/lora_adapter \
  --output_dir exports
```

---

## 7. Phase 5 — Optional Cloud Deployment (Vertex AI)

If you want to scale to larger datasets or run training in the cloud:

### 7.1 Build & Push Container
```bash
DOCKER_BUILDKIT=1 docker build -t qwen3.5-train:v1.0.0 .

# Push to Artifact Registry (optional)
PROJECT_ID=my-project REGION=us-central1 \
  ~/container-engineering/scripts/build-and-push.sh v1.0.0
```

### 7.2 Upload Dataset to GCS
```bash
gcloud storage cp -r ./data/formatted_dataset/ \
  gs://my-project-qwen35-ft/datasets/qwen3.5-2b-v1/
```

### 7.3 Submit Vertex AI Job
Edit `configs/vertex_job.yaml` with your project details, then:
```bash
uv run tasks.py submit --project-id my-project --bucket-name my-project-qwen35-ft
```

### 7.4 Monitor Job
```bash
uv run tasks.py monitor-last --region us-central1
```

---

## 8. File Structure

```
qwen3.5-2b-finetuning/
├── PLAN.md                       # This document
├── pyproject.toml                # uv project configuration
├── uv.lock                       # Locked dependencies
├── Dockerfile                    # Multi-stage GPU container (optional)
├── requirements.txt              # (legacy, see pyproject.toml)
├── configs/
│   ├── hf_qlora.yaml             # HF PEFT hyperparameters
│   └── vertex_job.yaml           # Vertex AI job config (optional)
├── data/
│   └── prepare_dataset.py        # Load + format dataset
├── train_hf_peft.py              # Primary training script (local)
├── inference.py                  # Quick local inference
├── export.py                     # Merge adapters / export GGUF
└── tasks.py                      # Invoke task runner (cloud helpers)
```

---

## 9. Hyperparameter Cheatsheet

| Param | HF PEFT | Notes |
|-------|---------|-------|
| rank (r) | 16 | Start here; 8 for tiny VRAM, 32 for complex tasks |
| lora_alpha | 32 | Standard 2:1 ratio |
| lora_dropout | 0.05 | Regularization |
| max_seq_length | 4096 | Qwen3.5 supports 262K; 4096 is a practical default |
| batch_size | 2 | Reduce to 1 if OOM |
| grad_accum | 4 | Effective batch = 8 |
| lr | 2e-4 | Standard for LoRA on small models |
| warmup_steps | 10 | Short for small datasets |
| max_steps | 60–500 | Scale with dataset size |

---

## 10. Local Execution Checklist

- [ ] Install `uv` and run `uv sync`
- [ ] Verify GPU with `torch.cuda.is_available()`
- [ ] Prepare dataset with `prepare_dataset.py`
- [ ] Review `configs/hf_qlora.yaml` hyperparameters
- [ ] Run training: `uv run python train_hf_peft.py`
- [ ] Test inference: `uv run python inference.py`
- [ ] Export model: `uv run python export.py --mode all`

### Optional Cloud Checklist
- [ ] Build and push Docker image
- [ ] Upload dataset to GCS
- [ ] Edit `configs/vertex_job.yaml` with project details
- [ ] Submit Vertex AI job via `tasks.py`
- [ ] Monitor and download results

---

## 11. Skills Used

| Skill | Purpose |
|-------|---------|
| `ml-training-pipeline` | Dataset formatting, LoRA/QLoRA patterns, training scripts |
| `container-engineering` | Multi-stage GPU Docker build (optional cloud path) |
| `cloud-job-orchestration` | Vertex AI custom job submission (optional) |
| `cloud-storage-artifacts` | GCS bucket, dataset upload (optional) |
| `cloud-infrastructure-setup` | GCP auth, project, APIs (optional) |
