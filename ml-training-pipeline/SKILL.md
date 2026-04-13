---
name: ml-training-pipeline
description: Fine-tune LLMs with TRL, PEFT, and PyTorch. Covers dataset preparation (HF Hub, format conversion, chat templates), model loading (BF16, quantization, Flash Attention), LoRA/QLoRA configuration, SFTTrainer training execution, and OOM debugging. Use when implementing fine-tuning workflows, preparing training data, configuring LoRA, debugging CUDA errors, or optimizing GPU memory.
---

<ml-training-pipeline>
This skill covers the complete workflow for fine-tuning large language models — from raw data to a trained adapter — using HuggingFace TRL, PEFT, and Transformers.

**What's covered:**
- `<data-preparation>` — Loading datasets, format conversion (Alpaca/ShareGPT → chat messages), applying chat templates with `prepare-dataset.py`
- `<model-loading>` — Precision (BF16), attention backends (Flash Attention 2, SDPA), quantization (4-bit/8-bit), gated model access
- `<lora-configuration>` — LoRA/QLoRA setup, rank selection, target modules per architecture
- `<training-execution>` — SFTTrainer, hyperparameters, optimizers, checkpointing with `train.py` and `config.yaml`
- `<debugging>` — OOM quick fixes, gradient issues, slow training diagnosis
- `<examples>` — End-to-end workflow: prepare data → load model → configure LoRA → train → validate

**Scripts:** `scripts/train.py` (main training), `scripts/prepare-dataset.py` (data preprocessing), `scripts/validate-model.py` (inference testing), `scripts/config.yaml` (config template)
**References:** `references/chat-templates.md`, `references/peft-patterns.md`, `references/oom-debugging.md`, `references/memory-optimization.md`, `references/official-docs.md`

**Core libraries:** `torch`, `transformers`, `datasets`, `peft`, `trl`, `bitsandbytes`, `accelerate`
Install: `pip install torch transformers datasets accelerate peft trl bitsandbytes`
Optional: `pip install flash-attn --no-build-isolation` (Flash Attention), `pip install wandb` (tracking)

**Approach:** Write the full command with actual variable names and model paths. Let the user run it, read the output together. Training logs show loss curves, learning rate, and throughput — read them to decide if the run is healthy.
</ml-training-pipeline>

<data-preparation>
Use `scripts/prepare-dataset.py` for all dataset preprocessing. Run without arguments to see usage.

```bash
# Convert Alpaca-format dataset to chat messages
python scripts/prepare-dataset.py --dataset tatsu-lab/alpaca --format chat --output ./data/

# Apply a model's chat template during conversion
python scripts/prepare-dataset.py --dataset tatsu-lab/alpaca --format chat --tokenizer meta-llama/Llama-2-7b-hf --output ./data/

# Local files with train/val split
python scripts/prepare-dataset.py --dataset json --data_files ./raw/data.json --format chat --output ./data/
```

The script handles: Alpaca → chat, ShareGPT → chat, deduplication (`--deduplicate`), length filtering (`--min_length`, `--max_length`), and train/val splitting (`--train_split 0.9`).

**Chat template formatting** — always use the model's native template via `tokenizer.apply_chat_template()`. This handles special tokens correctly per architecture (Llama, Mistral, Qwen). For tool-calling datasets, pass `tools=` to `apply_chat_template`. See `references/chat-templates.md` for model-specific formats and tool calling examples.

**Training only on completions** — use `DataCollatorForCompletionOnlyLM` to mask user turns and compute loss only on assistant responses:
```python
from trl import DataCollatorForCompletionOnlyLM
collator = DataCollatorForCompletionOnlyLM(response_template="### Response:\n", tokenizer=tokenizer)
```

Run `prepare-dataset.py`. Read the output — it reports dataset size, format, split counts, and any rows removed by filtering. Check these numbers make sense before training.
</data-preparation>

<model-loading>
**Standard loading (BF16 + Flash Attention 2)** — the recommended default:
```python
model = AutoModelForCausalLM.from_pretrained(
    model_id,
    torch_dtype=torch.bfloat16,
    attn_implementation="flash_attention_2",
    device_map="auto",
)
```
Use `attn_implementation="sdpa"` if Flash Attention is unavailable (older GPUs). Use `"eager"` only for debugging.

**4-bit quantization (QLoRA)** — fits large models on smaller GPUs:
```python
from transformers import BitsAndBytesConfig
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,
)
model = AutoModelForCausalLM.from_pretrained(model_id, quantization_config=bnb_config, device_map="auto")
```

**8-bit** — middle ground: `AutoModelForCausalLM.from_pretrained(model_id, load_in_8bit=True, device_map="auto")`

**Gated models** — set `HF_TOKEN` env var, or call `huggingface_hub.login(token=os.getenv("HF_TOKEN"))` before loading. The `train.py` script reads `HF_TOKEN` automatically.

**Tokenizer** — always set pad token if missing:
```python
tokenizer = AutoTokenizer.from_pretrained(model_id)
if tokenizer.pad_token is None:
    tokenizer.pad_token = tokenizer.eos_token
```
</model-loading>

<lora-configuration>
LoRA adds small trainable matrices to frozen model weights. QLoRA combines 4-bit quantization with LoRA.

**Standard LoRA:**
```python
from peft import LoraConfig, get_peft_model, TaskType
lora_config = LoraConfig(
    r=16, lora_alpha=32,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
    lora_dropout=0.05, bias="none", task_type=TaskType.CAUSAL_LM,
)
model = get_peft_model(model, lora_config)
model.print_trainable_parameters()
```

**QLoRA** — load in 4-bit first, then prepare and apply LoRA:
```python
from peft import prepare_model_for_kbit_training
model = prepare_model_for_kbit_training(model)  # after 4-bit loading
model = get_peft_model(model, lora_config)
```

**Rank selection:** `r=8-16` for quick experiments, `r=32-64` for complex tasks, `r=128` for maximum quality on large models. Alpha is typically `2×r`. See `references/peft-patterns.md` for rank-by-model-size table and advanced variants (DoRA, AdaLoRA, IA³).

**Target modules by architecture:**
- Llama/Mistral/Qwen: `q_proj`, `k_proj`, `v_proj`, `o_proj`, `gate_proj`, `up_proj`, `down_proj`
- GPT-2: `c_attn`, `c_proj`, `c_fc`
- GPT-NeoX/BLOOM: `query_key_value`, `dense`

The `train.py` script auto-detects target modules from `model.config.model_type`.
</lora-configuration>

<training-execution>
Use `scripts/train.py` as the primary training script. Run without arguments to see all options.

```bash
# LoRA fine-tuning
python scripts/train.py --model_id meta-llama/Llama-2-7b-hf --dataset tatsu-lab/alpaca --use_lora

# QLoRA (4-bit)
python scripts/train.py --model_id meta-llama/Llama-2-7b-hf --dataset tatsu-lab/alpaca --load_in_4bit --lora_r 32

# Multi-GPU
accelerate launch --num_processes=4 scripts/train.py --model_id meta-llama/Llama-2-7b-hf --use_lora
```

**Key hyperparameters:**

| Parameter | Default | Notes |
|-----------|---------|-------|
| `--batch_size` | 1 | Reduce first if OOM |
| `--gradient_accumulation_steps` | 8 | Effective batch = batch_size × this |
| `--learning_rate` | 2e-4 | LoRA range: 1e-4 to 5e-4 |
| `--lr_scheduler` | cosine | Usually better convergence than linear |
| `--num_epochs` | 3 | Or use `--max_steps` |
| `--max_seq_length` | 2048 | Reduce if OOM |

**Optimizers:** `adamw_torch_fused` (default), `paged_adamw_8bit` (QLoRA — pages optimizer states to CPU).

**Checkpointing:** `--save_steps 500 --save_total_limit 3`. The script auto-resumes from the latest checkpoint if `output_dir` contains one.

**Tracking:** `--report_to wandb` (set `WANDB_API_KEY`) or `--report_to tensorboard`. View TensorBoard logs: `tensorboard --logdir ./results/logs`.

All parameters also configurable via `scripts/config.yaml`. See `references/official-docs.md` for TRL/Transformers/PEFT documentation links.

Run `train.py`. Read the output — early logs show trainable parameter count, dataset size, and estimated training time. Watch the loss: it should decrease steadily. If loss plateaus early or spikes, adjust learning rate.
</training-execution>

<debugging>
**OOM — try in order:**
1. `--batch_size 1` with higher `--gradient_accumulation_steps`
2. `--gradient_checkpointing` (enabled by default in `train.py`)
3. Reduce `--max_seq_length` (2048 → 1024)
4. Reduce `--lora_r` (64 → 16)
5. Use `--load_in_4bit` (QLoRA)
6. Set `PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True` to reduce CUDA fragmentation

**Gradient issues:** `--max_grad_norm 1.0` (default). If loss is NaN, check data for empty examples and reduce learning rate.

**Slow training:** Ensure `--bf16` is active (2× faster on Ampere+). Use `--attn_implementation flash_attention_2`. Check GPU utilization with `nvidia-smi dmon`.

**Multi-GPU / large models:** Use DeepSpeed ZeRO-2/3 or FSDP for sharding across GPUs. See `references/memory-optimization.md` for configs and `references/oom-debugging.md` for memory profiling tools.

**Memory reference table (QLoRA, batch=1, seq=2048):**

| Model | VRAM Required |
|-------|---------------|
| 7B | ~8-12 GB |
| 13B | ~14-20 GB |
| 70B | ~40-48 GB |
</debugging>

<ml-training-scripts>
All scripts show usage when run without arguments.

| Script | Purpose |
|--------|---------|
| `train.py` | Main training script — LoRA/QLoRA, multi-GPU, all hyperparameters via CLI or env vars |
| `prepare-dataset.py` | Dataset loading, format conversion, filtering, deduplication, train/val splitting |
| `validate-model.py` | Quick inference test — single prompt, batch file, or interactive mode; auto-detects LoRA adapters |
| `config.yaml` | Example training configuration template with all parameters documented |
</ml-training-scripts>

<ml-training-reference>
| File | Contents |
|------|----------|
| `references/chat-templates.md` | Chat template formats per model (Llama, Mistral, Qwen), tool calling dataset format, response masking |
| `references/peft-patterns.md` | LoRA rank-by-model-size table, target modules per architecture, advanced variants (DoRA, AdaLoRA), merging adapters |
| `references/oom-debugging.md` | OOM diagnosis checklist, memory profiling with PyTorch, CUDA snapshot debugging, error-specific solutions |
| `references/memory-optimization.md` | Technique comparison table, DeepSpeed/FSDP configs, GPU-specific recommendations (24GB/48GB/80GB) |
| `references/official-docs.md` | Links to TRL, Transformers, PEFT, Accelerate, DeepSpeed, Datasets, BitsAndBytes, W&B documentation |
</ml-training-reference>

<examples>
**Scenario:** Fine-tune Llama-2-7B on the Alpaca dataset with LoRA, then validate.

**Step 1 — Prepare data:**
```bash
python scripts/prepare-dataset.py \
    --dataset tatsu-lab/alpaca \
    --format chat \
    --tokenizer meta-llama/Llama-2-7b-hf \
    --output ./data/alpaca-chat
```
Read the output — it reports row count, format conversion results, and split sizes. If rows were dropped, check `--min_length` and `--max_length`.

**Step 2 — Train with LoRA:**
```bash
python scripts/train.py \
    --model_id meta-llama/Llama-2-7b-hf \
    --dataset json --data_files ./data/alpaca-chat/train.jsonl \
    --use_lora --lora_r 16 --lora_alpha 32 \
    --learning_rate 2e-4 --num_epochs 3 \
    --output_dir ./results/llama-alpaca-lora \
    --report_to tensorboard
```
Read the early output — it shows trainable parameters (should be ~0.5-2% of total), dataset size, and steps per epoch. Watch the loss curve.

**Step 3 — Validate the trained model:**
```bash
python scripts/validate-model.py \
    --model_path ./results/llama-alpaca-lora \
    --prompt "Explain what fine-tuning means in machine learning."
```
Read the output — it auto-detects the LoRA adapter and shows the generated text. Compare it with the base model to see if training had an effect.

**Step 4 — Interactive testing:**
```bash
python scripts/validate-model.py --model_path ./results/llama-alpaca-lora --interactive
```

**Common mistake — OOM on a 24GB GPU with defaults:**
```bash
# Bad: default seq length is too long for the dataset
python scripts/train.py --model_id meta-llama/Llama-2-7b-hf --use_lora --max_seq_length 4096
# → CUDA out of memory

# Good: reduce sequence length and use QLoRA
python scripts/train.py --model_id meta-llama/Llama-2-7b-hf --load_in_4bit --max_seq_length 2048
```
If you hit OOM, read the error — it shows how much memory was requested vs. available. Follow the debugging steps in `<debugging>` in order.
</examples>
