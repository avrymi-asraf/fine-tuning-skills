# OOM Debugging Guide

Comprehensive guide to diagnosing and fixing CUDA Out of Memory errors.

## Quick Fixes (Try in Order)

1. **Reduce batch size**: `per_device_train_batch_size=1`
2. **Increase gradient accumulation**: `gradient_accumulation_steps=8`
3. **Enable gradient checkpointing**: `gradient_checkpointing=True`
4. **Reduce sequence length**: `max_seq_length=1024`
5. **Use smaller LoRA rank**: `r=8` instead of `r=64`
6. **Enable 4-bit quantization**: QLoRA

## Understanding GPU Memory Usage

### Memory Components

```
Total GPU Memory:
├── Model Parameters (weights)
├── Optimizer States (Adam: 2x params, 8-bit: 1x params)
├── Gradients (1x params)
├── Activations (depends on batch size, seq length, layers)
└── CUDA/Fragmentation overhead (~10-20%)
```

### Formula (LoRA Training)

```
Memory ≈ Model Size + (Optimizer States + Gradients for trainable params) + Activations

QLoRA 7B:
- Model: ~4GB (4-bit)
- Trainable (0.1%): ~8MB
- Optimizer: ~16MB
- Activations (bs=1, seq=2048): ~2-4GB
- Total: ~8-12GB
```

## Diagnostic Tools

### 1. PyTorch Memory Summary

```python
import torch

# Print memory summary
print(torch.cuda.memory_summary(device=0, abbreviated=False))

# Key metrics
allocated = torch.cuda.memory_allocated() / 1e9
reserved = torch.cuda.memory_reserved() / 1e9
max_allocated = torch.cuda.max_memory_allocated() / 1e9

print(f"Allocated: {allocated:.2f}GB")
print(f"Reserved: {reserved:.2f}GB")
print(f"Max Allocated: {max_allocated:.2f}GB")
```

### 2. Memory Profiling

```python
from torch.profiler import profile, ProfilerActivity

with profile(
    activities=[ProfilerActivity.CPU, ProfilerActivity.CUDA],
    profile_memory=True,
    record_shapes=True
) as prof:
    # Training step
    outputs = model(**inputs)
    loss = outputs.loss
    loss.backward()

print(prof.key_averages().table(sort_by="cuda_memory_usage", row_limit=10))
```

### 3. Memory Snapshots

```python
import pickle

# Start recording
torch.cuda.memory._record_memory_history()

# ... run training ...

# Dump snapshot on OOM
try:
    trainer.train()
except RuntimeError as e:
    if "out of memory" in str(e):
        snapshot = torch.cuda.memory._snapshot()
        with open("oom_snapshot.pickle", "wb") as f:
            pickle.dump(snapshot, f)
        torch.cuda.memory._dump_snapshot("oom_snapshot.html")
    raise

# Visualize at: https://pytorch.org/memory_viz
```

## Common OOM Scenarios

### 1. Batch Size Too Large

**Symptom**: OOM during forward pass
**Fix**:
```python
training_args = TrainingArguments(
    per_device_train_batch_size=1,  # Start here
    gradient_accumulation_steps=16,  # Maintain effective batch size
)
```

### 2. Sequence Length Too Long

**Symptom**: OOM varies by sample
**Fix**:
```python
# Filter dataset
def filter_length(example):
    return len(example["text"]) < 4000  # Adjust threshold

dataset = dataset.filter(filter_length)

# Or truncate
trainer = SFTTrainer(
    max_seq_length=2048,  # Reduce from 4096
    ...
)
```

### 3. Gradients Too Large

**Symptom**: OOM during backward pass
**Fix**:
```python
training_args = TrainingArguments(
    max_grad_norm=1.0,  # Gradient clipping
    fp16=True,  # Or bf16=True for mixed precision
    gradient_accumulation_steps=4,  # More accumulation
)
```

### 4. Activations Too Large

**Symptom**: OOM scales with sequence length
**Fix**:
```python
# Enable gradient checkpointing
model.gradient_checkpointing_enable()

# Or in TrainingArguments
training_args = TrainingArguments(
    gradient_checkpointing=True,
)
```

### 5. CUDA Fragmentation

**Symptom**: OOM despite seemingly enough memory
**Fix**:
```python
import os
os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"

# Or set max split size
os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "max_split_size_mb:512"
```

## Advanced Solutions

### DeepSpeed ZeRO

```python
# ds_config.json
{
    "fp16": {
        "enabled": true
    },
    "bf16": {
        "enabled": false
    },
    "zero_optimization": {
        "stage": 2,  # Stage 2 or 3
        "offload_optimizer": {
            "device": "cpu",
            "pin_memory": true
        },
        "allgather_partitions": true,
        "allgather_bucket_size": 2e8,
        "overlap_comm": true,
        "reduce_scatter": true,
    },
    "train_batch_size": "auto",
    "train_micro_batch_size_per_gpu": "auto",
    "gradient_accumulation_steps": "auto",
}
```

Run with:
```bash
deepspeed --num_gpus=4 train.py --deepspeed ds_config.json
```

### FSDP (PyTorch Native)

```python
training_args = TrainingArguments(
    fsdp=["full_shard", "auto_wrap"],
    fsdp_config={
        "min_num_params": 1e8,
        "backward_prefetch": "backward_pre",
        "cpu_offload": True,
    },
)
```

### 8-bit Optimizers

```python
from bitsandbytes.optim import AdamW8bit

optimizer = AdamW8bit(model.parameters(), lr=2e-4)

training_args = TrainingArguments(
    optim="adamw_8bit",  # Built-in support
)
```

### Page Optimizers (QLoRA)

```python
training_args = TrainingArguments(
    optim="paged_adamw_8bit",  # Pages optimizer states to CPU
)
```

## Memory-Efficient Training Config

```python
from transformers import TrainingArguments, BitsAndBytesConfig
from peft import LoraConfig

# 4-bit quantization
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,
)

# Small LoRA
lora_config = LoraConfig(
    r=8,  # Small rank
    lora_alpha=16,
    target_modules=["q_proj", "v_proj"],  # Minimal modules
    lora_dropout=0.05,
)

# Memory-optimized training args
training_args = TrainingArguments(
    per_device_train_batch_size=1,
    gradient_accumulation_steps=16,
    max_grad_norm=0.3,  # Aggressive clipping
    warmup_ratio=0.03,
    lr_scheduler_type="cosine",
    gradient_checkpointing=True,
    group_by_length=True,  # Reduce padding
    optim="paged_adamw_8bit",
    bf16=True,
)
```

## Checking Memory Before Training

```python
def estimate_memory(
    model_params: int,
    batch_size: int = 1,
    seq_length: int = 2048,
    dtype_bytes: int = 2,  # BF16
    trainable_percent: float = 0.1,
    optimizer_multiplier: float = 12,  # Adam
):
    """Estimate training memory in GB."""

    # Model weights
    model_memory = (model_params * dtype_bytes) / 1e9

    # Trainable params
    trainable_params = model_params * (trainable_percent / 100)

    # Optimizer states + gradients
    optimizer_memory = (trainable_params * optimizer_multiplier * 4) / 1e9

    # Activations (rough estimate)
    activation_memory = (batch_size * seq_length * model_params * 4 * 1e-4) / 1e9

    # Overhead
    overhead = 2  # GB

    total = model_memory + optimizer_memory + activation_memory + overhead

    print(f"Model: {model_memory:.2f}GB")
    print(f"Optimizer/Gradients: {optimizer_memory:.2f}GB")
    print(f"Activations: {activation_memory:.2f}GB")
    print(f"Overhead: {overhead}GB")
    print(f"Total Estimate: {total:.2f}GB")

    return total

# Example: 7B model, LoRA 0.1%
estimate_memory(7e9, trainable_percent=0.1)
```

## Error-Specific Solutions

### "CUDA out of memory. Tried to allocate X MiB"

**Causes**:
- Batch too large
- Sequence too long
- Concurrent allocations

**Fixes**:
```python
# Clear cache
torch.cuda.empty_cache()

# Reduce fragmentation
os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"

# Use smaller batches with accumulation
training_args.per_device_train_batch_size = 1
training_args.gradient_accumulation_steps = 32
```

### "RuntimeError: CUDA error: out of memory" in backward

**Causes**:
- Gradient memory accumulation
- Large intermediate activations

**Fixes**:
```python
# Enable gradient checkpointing
model.gradient_checkpointing_enable()

# Use checkpointing in args
training_args.gradient_checkpointing = True

# Reduce batch/sequence
```

### OOM During Model Loading

**Fixes**:
```python
# Use empty_init for large models
with init_empty_weights():
    model = AutoModelForCausalLM.from_config(config)

# Or load with device_map
model = AutoModelForCausalLM.from_pretrained(
    model_id,
    device_map="auto",
    max_memory={0: "40GB", 1: "40GB"},  # Per GPU limit
)
```

## Monitoring During Training

```python
from transformers import TrainerCallback

class MemoryMonitorCallback(TrainerCallback):
    def on_step_end(self, args, state, control, **kwargs):
        if state.global_step % 50 == 0:
            allocated = torch.cuda.memory_allocated() / 1e9
            reserved = torch.cuda.memory_reserved() / 1e9
            print(f"Step {state.global_step}: {allocated:.2f}GB allocated, {reserved:.2f}GB reserved")

# Add to trainer
trainer = SFTTrainer(
    callbacks=[MemoryMonitorCallback()],
    ...
)
```

## Debugging Checklist

- [ ] Batch size is 1 (increase after success)
- [ ] Gradient checkpointing enabled
- [ ] Sequence length minimized
- [ ] LoRA rank is 8-16 (increase after success)
- [ ] 4-bit quantization for large models
- [ ] `expandable_segments` environment variable set
- [ ] No other processes on GPU (check `nvidia-smi`)
- [ ] Using `paged_adamw_8bit` optimizer for QLoRA
