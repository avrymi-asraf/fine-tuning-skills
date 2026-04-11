---
name: ml-training-pipeline
description: Complete ML fine-tuning pipeline with TRL, PEFT, and PyTorch. Covers dataset preparation (HF Hub, custom data, format conversion), chat template formatting for tool calling and conversations, model loading strategies (BF16, quantization, Flash Attention, SDPA), parameter-efficient training (LoRA/QLoRA, freezing layers), training configuration (hyperparameters, schedulers, optimizers, checkpointing), SFTTrainer/Trainer/Accelerate patterns, gated model access (HF_TOKEN), debugging OOM/CUDA errors, and monitoring with W&B/TensorBoard. Use when implementing LLM fine-tuning workflows, preparing training data, configuring training jobs, debugging training failures, or optimizing memory usage.
---

# ML Training Pipeline

Complete guide to fine-tuning Large Language Models using modern tools and best practices.

## Overview

This skill provides workflows for the complete ML training lifecycle:
1. **Data Preparation** — Load, format, and validate training data
2. **Model Setup** — Load with optimal settings (precision, attention, quantization)
3. **Training Configuration** — LoRA/QLoRA, hyperparameters, optimizers
4. **Execution** — Run training with proper monitoring and checkpointing
5. **Debugging** — Diagnose and fix common failures

## Quick Start

```python
from trl import SFTTrainer
from peft import LoraConfig
from transformers import AutoModelForCausalLM, AutoTokenizer

# 1. Load model with memory-efficient settings
model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-2-7b-hf",
    torch_dtype=torch.bfloat16,
    attn_implementation="flash_attention_2",
    device_map="auto",
)

# 2. Configure LoRA
peft_config = LoraConfig(
    r=16, lora_alpha=32, target_modules=["q_proj", "v_proj"],
    lora_dropout=0.05, bias="none", task_type="CAUSAL_LM"
)

# 3. Train with SFTTrainer
trainer = SFTTrainer(
    model=model,
    train_dataset=dataset,
    peft_config=peft_config,
    max_seq_length=2048,
)
trainer.train()
```

## Prerequisites

```bash
pip install torch transformers datasets accelerate peft trl bitsandbytes
pip install flash-attn --no-build-isolation  # Optional: Flash Attention
pip install wandb  # Optional: experiment tracking
```

## Dataset Preparation

### Loading from HuggingFace Hub

```python
from datasets import load_dataset

# Standard dataset
dataset = load_dataset("tatsu-lab/alpaca", split="train")

# Gated dataset (requires HF_TOKEN)
dataset = load_dataset("nvidia/OpenMathInstruct-1", split="train")

# With streaming for large datasets
dataset = load_dataset("bigcode/the-stack", streaming=True, split="train")
```

### Format Conversion

**Conversations format (standard):**
```python
def format_conversation(example):
    return {
        "messages": [
            {"role": "system", "content": example["instruction"]},
            {"role": "user", "content": example["input"]},
            {"role": "assistant", "content": example["output"]}
        ]
    }

dataset = dataset.map(format_conversation)
```

**Text completion format:**
```python
def format_text(example):
    text = f"### Instruction:\n{example['instruction']}\n\n### Response:\n{example['output']}"
    return {"text": text}
```

### Chat Templates & Tool Calling

Apply the model's chat template for proper formatting:

```python
def apply_chat_template(example, tokenizer):
    messages = example["messages"]
    text = tokenizer.apply_chat_template(
        messages,
        tokenize=False,
        add_generation_prompt=False
    )
    return {"text": text}

# With tool calling support
tools = [{
    "type": "function",
    "function": {
        "name": "get_weather",
        "description": "Get weather for a location",
        "parameters": {...}
    }
}]

text = tokenizer.apply_chat_template(
    messages,
    tools=tools,
    tokenize=False
)
```

See `references/chat-templates.md` for complete tool calling examples.

## Model Loading Strategies

### Precision & Attention

```python
from transformers import AutoModelForCausalLM, BitsAndBytesConfig

# BF16 + Flash Attention 2 (recommended)
model = AutoModelForCausalLM.from_pretrained(
    model_id,
    torch_dtype=torch.bfloat16,
    attn_implementation="flash_attention_2",
    device_map="auto",
)

# 4-bit quantization with QLoRA
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,
)
model = AutoModelForCausalLM.from_pretrained(
    model_id,
    quantization_config=bnb_config,
    device_map="auto",
    attn_implementation="flash_attention_2",
)

# 8-bit quantization (middle ground)
model = AutoModelForCausalLM.from_pretrained(
    model_id,
    load_in_8bit=True,
    device_map="auto",
)
```

### Freezing Strategies

```python
# Freeze vision encoder (multimodal models)
for param in model.vision_tower.parameters():
    param.requires_grad = False

# Freeze embedding layers
model.get_input_embeddings().requires_grad_(False)

# Freeze specific layers (e.g., first half)
for layer in model.model.layers[:16]:
    for param in layer.parameters():
        param.requires_grad = False
```

## Parameter-Efficient Fine-Tuning

### LoRA Configuration

```python
from peft import LoraConfig, get_peft_model, TaskType

# Standard LoRA for LLMs
lora_config = LoraConfig(
    r=16,                    # Rank (4-128, higher = more params)
    lora_alpha=32,           # Scaling (usually 2*r)
    target_modules=[         # Modules to adapt
        "q_proj", "k_proj", "v_proj", "o_proj",
        "gate_proj", "up_proj", "down_proj"
    ],
    lora_dropout=0.05,
    bias="none",
    task_type=TaskType.CAUSAL_LM,
)

model = get_peft_model(model, lora_config)
model.print_trainable_parameters()  # Verify % of trainable params
```

### QLoRA (4-bit + LoRA)

```python
from transformers import BitsAndBytesConfig
from peft import prepare_model_for_kbit_training

# 1. Load in 4-bit
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,
)
model = AutoModelForCausalLM.from_pretrained(
    model_id,
    quantization_config=bnb_config,
    device_map="auto",
)

# 2. Prepare for training
model = prepare_model_for_kbit_training(model)

# 3. Apply LoRA
model = get_peft_model(model, lora_config)
```

### LoRA Hyperparameter Guide

| Parameter | Range | Notes |
|-----------|-------|-------|
| `r` (rank) | 4-128 | Higher = more capacity, more memory |
| `lora_alpha` | 8-256 | Usually 2× rank |
| `lora_dropout` | 0.0-0.1 | Regularization |
| `target_modules` | varies | See below for common patterns |

**Common target_modules by model:**
- Llama/Qwen: `["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"]`
- GPT-2: `["c_attn", "c_proj", "c_fc"]`
- Mistral: Same as Llama

See `references/peft-patterns.md` for advanced PEFT strategies.

## Training Configuration

### Hyperparameters

```python
training_args = TrainingArguments(
    # Batch sizes
    per_device_train_batch_size=1,      # Reduce if OOM
    gradient_accumulation_steps=8,      # Effective batch = 8
    
    # Training length
    num_train_epochs=3,
    max_steps=-1,  # Override epochs if set
    
    # Learning rate
    learning_rate=2e-4,  # LoRA: 1e-4 to 5e-4
    lr_scheduler_type="cosine",
    warmup_ratio=0.03,
    
    # Optimization
    optim="paged_adamw_8bit",  # QLoRA
    # optim="adamw_torch",      # Standard
    
    # Logging & Checkpointing
    logging_steps=10,
    save_strategy="steps",
    save_steps=500,
    eval_strategy="steps",
    eval_steps=500,
    
    # Memory
    gradient_checkpointing=True,
    bf16=True,  # Use fp16 if no BF16 support
    
    # Output
    output_dir="./results",
    report_to="wandb",  # or "tensorboard"
)
```

### Optimizer Selection

| Optimizer | Use Case | Notes |
|-----------|----------|-------|
| `adamw_torch` | Standard training | Default, reliable |
| `paged_adamw_8bit` | QLoRA | Reduces memory |
| `paged_adamw_32bit` | Full fine-tune | Lower memory than standard |
| `galore_adamw` | Full fine-tune large models | Gradient low-rank projection |

### Scheduler Types

- `linear` (default): Linear decay after warmup
- `cosine`: Cosine annealing, often better convergence
- `constant`: No decay
- `polynomial`: Polynomial decay
- `inverse_sqrt`: Good for transformers

## SFTTrainer Usage

### Basic Training

```python
from trl import SFTTrainer

trainer = SFTTrainer(
    model=model,
    tokenizer=tokenizer,
    train_dataset=train_dataset,
    eval_dataset=eval_dataset,
    peft_config=lora_config,  # Optional: for LoRA
    max_seq_length=2048,
    dataset_text_field="text",  # Field containing formatted text
    args=training_args,
)

trainer.train()
trainer.save_model("./final_model")
```

### With Data Collator

```python
from trl import DataCollatorForCompletionOnlyLM

# Only compute loss on assistant responses
collator = DataCollatorForCompletionOnlyLM(
    tokenizer=tokenizer,
    response_template="### Response:\n",  # Mark assistant starts
)

trainer = SFTTrainer(
    ...,
    data_collator=collator,
)
```

## Monitoring & Logging

### Weights & Biases

```python
import wandb

# Login (or set WANDB_API_KEY env var)
wandb.login()

# Initialize run
wandb.init(
    project="llm-fine-tuning",
    name="llama2-7b-lora-v1",
    config={
        "model": "meta-llama/Llama-2-7b-hf",
        "lora_r": 16,
        "learning_rate": 2e-4,
    }
)

# In TrainingArguments
report_to="wandb"
```

### TensorBoard

```bash
tensorboard --logdir ./results/runs
```

### Custom Callbacks

```python
from transformers import TrainerCallback

class MemoryCallback(TrainerCallback):
    def on_step_end(self, args, state, control, **kwargs):
        if state.global_step % 100 == 0:
            allocated = torch.cuda.memory_allocated() / 1e9
            print(f"Step {state.global_step}: {allocated:.2f}GB allocated")
```

## Debugging Common Issues

### CUDA Out of Memory (OOM)

**Immediate fixes:**
1. Reduce `per_device_train_batch_size` to 1
2. Increase `gradient_accumulation_steps`
3. Enable `gradient_checkpointing=True`
4. Reduce `max_seq_length`
5. Use smaller LoRA rank (`r`)

**Advanced:**
```python
# Enable memory efficient attention
attn_implementation="flash_attention_2"  # or "sdpa"

# Use DeepSpeed ZeRO-3 for sharding
deepspeed_config = {
    "zero_optimization": {
        "stage": 3,
        "offload_optimizer": {"device": "cpu"},
    },
    "train_batch_size": "auto",
}
```

See `references/oom-debugging.md` for detailed memory profiling.

### Gradient Issues

```python
# Gradient clipping
training_args.max_grad_norm = 1.0

# Check for NaN/Inf
training_args.ddp_find_unused_parameters = False
```

### Slow Training

- Ensure `bf16=True` (2× faster than fp32 on Ampere+)
- Use Flash Attention 2
- Check GPU utilization: `nvidia-smi dmon`
- Profile with PyTorch profiler

## Training Script Best Practices

See `scripts/train.py` for a complete, adaptable template.

### Environment Variable Configuration

```python
import os

# Model & data
MODEL_ID = os.getenv("MODEL_ID", "meta-llama/Llama-2-7b-hf")
DATASET_NAME = os.getenv("DATASET_NAME", "tatsu-lab/alpaca")
OUTPUT_DIR = os.getenv("OUTPUT_DIR", "./results")

# Training
LEARNING_RATE = float(os.getenv("LEARNING_RATE", "2e-4"))
NUM_EPOCHS = int(os.getenv("NUM_EPOCHS", "3"))
BATCH_SIZE = int(os.getenv("BATCH_SIZE", "1"))
GRAD_ACCUM = int(os.getenv("GRAD_ACCUM", "8"))
MAX_SEQ_LENGTH = int(os.getenv("MAX_SEQ_LENGTH", "2048"))

# LoRA
LORA_R = int(os.getenv("LORA_R", "16"))
LORA_ALPHA = int(os.getenv("LORA_ALPHA", "32"))
```

### Checkpoint Resumption

```python
# Auto-resume from latest checkpoint
last_checkpoint = None
if os.path.isdir(output_dir) and len(os.listdir(output_dir)) > 0:
    last_checkpoint = get_last_checkpoint(output_dir)

trainer.train(resume_from_checkpoint=last_checkpoint)
```

## Accelerate Integration

```bash
# Launch config
accelerate config

# Multi-GPU training
accelerate launch --num_processes=4 train.py

# DeepSpeed integration
accelerate launch --deepspeed_config ds_config.json train.py
```

## Gated Model Access

```python
import os
from huggingface_hub import login

# Method 1: Environment variable
# export HF_TOKEN=your_token

# Method 2: Login programmatically
login(token=os.getenv("HF_TOKEN"))

# Method 3: Use token in from_pretrained
model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-2-7b-hf",
    token=os.getenv("HF_TOKEN"),
    ...
)
```

## Resources

- `scripts/train.py` — Complete training script template
- `scripts/prepare-dataset.py` — Dataset preprocessing
- `scripts/validate-model.py` — Quick inference validation
- `references/chat-templates.md` — Tool calling & formatting
- `references/peft-patterns.md` — Advanced LoRA/QLoRA
- `references/oom-debugging.md` — Memory debugging guide
- `references/official-docs.md` — Links to TRL, Transformers, etc.
