# Memory Optimization Techniques

Comprehensive guide to reducing GPU memory usage during LLM training.

## Technique Comparison

| Technique | Memory Savings | Speed Impact | Quality Impact | Implementation |
|-----------|---------------|--------------|----------------|----------------|
| Gradient Checkpointing | 30-50% | ~20% slower | None | Easy |
| Mixed Precision (BF16) | 50% | 2-3x faster | None | Easy |
| Flash Attention 2 | 20-40% | 2-3x faster | None | Easy |
| LoRA | 90-99.9% | Similar | Minimal | Easy |
| QLoRA (4-bit) | 75% | ~10% slower | Minimal | Easy |
| 8-bit Adam | 50% optimizer | Similar | None | Easy |
| Gradient Accumulation | Scales with steps | Linear | None | Easy |
| DeepSpeed ZeRO-3 | 4x GPU count | Communication overhead | None | Moderate |
| FSDP | 4x GPU count | Communication overhead | None | Moderate |
| Sequence Packing | 20-50% | Similar | None | Moderate |

## 1. Gradient Checkpointing

Trade compute for memory by recomputing activations during backward pass.

```python
# Enable in model
model.gradient_checkpointing_enable()

# Or in TrainingArguments
training_args = TrainingArguments(
    gradient_checkpointing=True,
)

# Must enable for LoRA compatibility
if training_args.gradient_checkpointing:
    model.enable_input_require_grads()
```

**Memory**: 30-50% reduction
**Speed**: ~20% slower
**Use when**: Always enable for large models

## 2. Mixed Precision Training

```python
# BF16 (Ampere GPUs and newer)
training_args = TrainingArguments(
    bf16=True,
)

# FP16 (older GPUs)
training_args = TrainingArguments(
    fp16=True,
)
```

**Memory**: 50% reduction for activations
**Speed**: 2-3x faster on supported hardware
**Use when**: BF16 on Ampere+ (A100, H100, RTX 30xx+), FP16 on older GPUs

## 3. Flash Attention 2

Memory-efficient exact attention implementation.

```python
model = AutoModelForCausalLM.from_pretrained(
    model_id,
    attn_implementation="flash_attention_2",
    torch_dtype=torch.bfloat16,
)
```

Installation:
```bash
pip install flash-attn --no-build-isolation
```

**Memory**: 20-40% reduction
**Speed**: 2-3x faster
**Use when**: Always for causal LM training

## 4. SDPA (Scaled Dot Product Attention)

PyTorch native efficient attention (fallback if Flash Attention unavailable).

```python
model = AutoModelForCausalLM.from_pretrained(
    model_id,
    attn_implementation="sdpa",
)
```

**Memory**: 10-20% reduction
**Speed**: 1.5-2x faster
**Use when**: Flash Attention not available

## 5. LoRA (Low-Rank Adaptation)

Train only small adapter matrices instead of full model.

```python
from peft import LoraConfig, get_peft_model

lora_config = LoraConfig(
    r=16,
    lora_alpha=32,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj"],
    lora_dropout=0.05,
)

model = get_peft_model(model, lora_config)
```

**Memory**: 90-99.9% reduction in trainable parameters
**Speed**: Similar to full fine-tuning
**Use when**: Most fine-tuning scenarios

## 6. QLoRA (4-bit + LoRA)

Quantize base model to 4-bit, train LoRA adapters.

```python
from transformers import BitsAndBytesConfig

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

# Prepare for training
from peft import prepare_model_for_kbit_training
model = prepare_model_for_kbit_training(model)
```

**Memory**: 75% reduction vs full precision
**Speed**: ~10% slower than LoRA
**Use when**: Limited GPU memory (fit 70B on 48GB)

## 7. 8-bit Optimizers

```python
# Use 8-bit AdamW
training_args = TrainingArguments(
    optim="adamw_8bit",
)

# Or paged optimizer for QLoRA
training_args = TrainingArguments(
    optim="paged_adamw_8bit",
)
```

**Memory**: 50% reduction in optimizer states
**Speed**: Similar
**Use when**: Full fine-tuning or large LoRA ranks

## 8. Gradient Accumulation

Simulate large batch sizes with small batches.

```python
training_args = TrainingArguments(
    per_device_train_batch_size=1,
    gradient_accumulation_steps=16,  # Effective batch = 16
)
```

**Memory**: Constant regardless of effective batch size
**Speed**: Linear slowdown with accumulation steps
**Use when**: Need large effective batch size on limited memory

## 9. Sequence Packing

Pack multiple short sequences into one to reduce padding.

```python
from trl import SFTTrainer

trainer = SFTTrainer(
    ...,
    packing=True,  # Enable packing
    max_seq_length=2048,
)
```

**Memory**: 20-50% reduction (depends on dataset)
**Speed**: Similar
**Use when**: Dataset has variable-length sequences

## 10. DeepSpeed ZeRO

Shard optimizer states, gradients, and parameters across GPUs.

```python
# ds_config_zero2.json
{
    "bf16": {"enabled": true},
    "zero_optimization": {
        "stage": 2,
        "offload_optimizer": {
            "device": "cpu",
            "pin_memory": true
        },
    },
}

# ds_config_zero3.json
{
    "bf16": {"enabled": true},
    "zero_optimization": {
        "stage": 3,
        "offload_optimizer": {"device": "cpu"},
        "offload_param": {"device": "cpu"},
    },
}
```

**Memory**: Scales with GPU count (near-linear)
**Speed**: Communication overhead
**Use when**: Multi-GPU training, very large models

## 11. FSDP (Fully Sharded Data Parallel)

PyTorch native sharding.

```python
training_args = TrainingArguments(
    fsdp=["full_shard", "auto_wrap"],
    fsdp_config={
        "min_num_params": 1e8,
        "cpu_offload": True,
    },
)
```

**Memory**: Scales with GPU count
**Speed**: Communication overhead
**Use when**: PyTorch native alternative to DeepSpeed

## 12. Activation Checkpointing Strategies

```python
# Selective checkpointing (transformers)
from transformers import TrainingArguments

training_args = TrainingArguments(
    # Full checkpointing
    gradient_checkpointing=True,
    
    # Or use_reentrant=False for better memory
    gradient_checkpointing_kwargs={"use_reentrant": False},
)
```

## 13. CUDA Memory Management

```python
import os

# Reduce fragmentation
os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"

# Or set max split size
os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "max_split_size_mb:512"

# Empty cache between epochs (not recommended during training)
torch.cuda.empty_cache()
```

## Recommended Configurations by GPU

### 24GB GPU (RTX 3090/4090)

```python
# 7B model
model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-2-7b-hf",
    torch_dtype=torch.bfloat16,
    attn_implementation="flash_attention_2",
)

lora_config = LoraConfig(r=16, lora_alpha=32, target_modules=[...])

training_args = TrainingArguments(
    per_device_train_batch_size=2,
    gradient_accumulation_steps=4,
    gradient_checkpointing=True,
    bf16=True,
    max_seq_length=2048,
)
```

### 48GB GPU (A6000, A40)

```python
# 13B model with LoRA
# Or 7B model full fine-tuning

# 13B QLoRA
bnb_config = BitsAndBytesConfig(load_in_4bit=True, ...)
model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-2-13b-hf",
    quantization_config=bnb_config,
)

lora_config = LoraConfig(r=64, lora_alpha=128)
```

### 80GB GPU (A100, H100)

```python
# 70B model with QLoRA
# Or 13B/30B full fine-tuning

# 70B QLoRA
model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-2-70b-hf",
    quantization_config=bnb_config,
    attn_implementation="flash_attention_2",
)

lora_config = LoraConfig(r=128, lora_alpha=256)
```

## Memory Profiling Tools

```python
# 1. PyTorch profiler
from torch.profiler import profile, ProfilerActivity

with profile(activities=[ProfilerActivity.CUDA], profile_memory=True) as prof:
    trainer.train()

print(prof.key_averages().table(sort_by="cuda_memory_usage"))

# 2. Simple monitoring
import pynvml
pynvml.nvmlInit()
handle = pynvml.nvmlDeviceGetHandleByIndex(0)
info = pynvml.nvmlDeviceGetMemoryInfo(handle)
print(f"Used: {info.used / 1e9:.2f}GB / {info.total / 1e9:.2f}GB")
```

## Debugging Memory Spikes

```python
class MemoryDebugCallback(TrainerCallback):
    def on_step_start(self, args, state, control, **kwargs):
        torch.cuda.reset_peak_memory_stats()
    
    def on_step_end(self, args, state, control, **kwargs):
        peak = torch.cuda.max_memory_allocated() / 1e9
        print(f"Step {state.global_step} peak: {peak:.2f}GB")

trainer.add_callback(MemoryDebugCallback())
```
