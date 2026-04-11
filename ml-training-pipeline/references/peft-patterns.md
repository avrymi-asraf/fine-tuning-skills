# PEFT Patterns & Advanced LoRA

Advanced parameter-efficient fine-tuning strategies.

## LoRA Rank Selection

### General Guidelines

| Model Size | Rank (r) | Alpha | Trainable % | Use Case |
|------------|----------|-------|-------------|----------|
| 7B | 8-16 | 16-32 | 0.1-0.3% | Quick experiments, simple tasks |
| 7B | 32-64 | 64-128 | 0.5-1% | Complex tasks, reasoning |
| 13B | 16-32 | 32-64 | 0.1-0.3% | Standard fine-tuning |
| 13B | 64-128 | 128-256 | 0.5-1% | Complex reasoning, code |
| 70B | 32-64 | 64-128 | 0.05-0.1% | Memory-constrained |
| 70B | 128-256 | 256-512 | 0.1-0.3% | Maximum quality |

### Alpha vs Rank

```python
# Standard: alpha = 2 * r
lora_config = LoraConfig(r=16, lora_alpha=32)

# More aggressive: alpha = 4 * r (stronger update)
lora_config = LoraConfig(r=16, lora_alpha=64)

# More conservative: alpha = r (gentler update)
lora_config = LoraConfig(r=16, lora_alpha=16)
```

## Target Module Patterns

### Attention Only (Memory Efficient)

```python
target_modules = ["q_proj", "v_proj"]  # ~30% of parameters
target_modules = ["q_proj", "k_proj", "v_proj"]  # ~45%
target_modules = ["q_proj", "k_proj", "v_proj", "o_proj"]  # ~60%
```

### Attention + MLP (More Capacity)

```python
target_modules = [
    "q_proj", "k_proj", "v_proj", "o_proj",
    "gate_proj", "up_proj", "down_proj"
]  # ~95% of parameters
```

### Model-Specific Targets

```python
# LLaMA / Mistral / Qwen
llama_targets = ["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"]

# GPT-2
gpt2_targets = ["c_attn", "c_proj", "c_fc"]

# GPT-J
gptj_targets = ["q_proj", "v_proj"]

# GPT-NeoX
gpt_neox_targets = ["query_key_value", "dense"]

# BLOOM
bloom_targets = ["query_key_value", "dense"]

# T5
t5_targets = ["q", "k", "v", "o", "wi", "wo"]

# Phi
phi_targets = ["q_proj", "k_proj", "v_proj", "dense", "fc1", "fc2"]
```

## QLoRA Deep Dive

### 4-bit Configuration

```python
from transformers import BitsAndBytesConfig

# Standard QLoRA (recommended)
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",        # NF4 for normal weights
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,   # Nested quantization
)

# FP4 alternative
fp4_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="fp4",
    bnb_4bit_compute_dtype=torch.float16,
)
```

### Double Quantization Explained

```python
# Double quant = quantize the quantization constants
# Reduces memory further with minimal quality loss
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_use_double_quant=True,  # Saves ~0.5GB for 7B model
)
```

## Freezing Strategies

### Freeze Embeddings

```python
model.get_input_embeddings().requires_grad_(False)
model.get_output_embeddings().requires_grad_(False)
```

### Freeze Early Layers

```python
# Freeze first N layers
num_freeze = 8
for layer in model.model.layers[:num_freeze]:
    for param in layer.parameters():
        param.requires_grad = False
```

### Freeze by Parameter Type

```python
# Only train attention
for name, param in model.named_parameters():
    if "attn" not in name:
        param.requires_grad = False
```

### Vision Tower (Multimodal)

```python
# Freeze vision encoder completely
for param in model.vision_tower.parameters():
    param.requires_grad = False
```

## Advanced LoRA Variants

### DoRA (Weight-Decomposed LoRA)

```python
from peft import LoraConfig

lora_config = LoraConfig(
    r=16,
    lora_alpha=32,
    use_dora=True,  # Enable DoRA
    target_modules=["q_proj", "v_proj"],
)
```

### AdaLoRA (Adaptive Rank)

```python
from peft import AdaLoraConfig

adalora_config = AdaLoraConfig(
    peft_type="ADALORA",
    r=8,
    target_modules=["q_proj", "v_proj"],
    lora_alpha=32,
)
```

### IA³ (Infused Adapter)

```python
from peft import IA3Config

ia3_config = IA3Config(
    peft_type="IA3",
    target_modules=["k_proj", "v_proj", "down_proj"],
    feedforward_modules=["down_proj"],
)
```

## LoRA + Gradient Checkpointing

```python
# Must enable input gradients for LoRA
training_args = TrainingArguments(
    gradient_checkpointing=True,
    ...
)

# SFTTrainer handles this automatically with PEFT
# For manual setup:
if training_args.gradient_checkpointing:
    model.enable_input_require_grads()
```

## Multi-Adapter Setup

### Loading Multiple Adapters

```python
from peft import PeftModel

# Load base model
base_model = AutoModelForCausalLM.from_pretrained("meta-llama/Llama-2-7b-hf")

# Load and merge first adapter
model = PeftModel.from_pretrained(base_model, "adapter1_path")
model = model.merge_and_unload()

# Load second adapter on merged model
model = PeftModel.from_pretrained(model, "adapter2_path")
```

### Adapter Switching

```python
# Set active adapter
model.set_adapter("coding_adapter")

# Disable all adapters
with model.disable_adapter():
    output = model.generate(**inputs)

# Add new adapter
model.add_adapter("new_task", lora_config)
```

## Memory Optimization Table

| Configuration | 7B Model | 13B Model | 70B Model |
|--------------|----------|-----------|-----------|
| Full Fine-tune (FP32) | 28GB | 52GB | 280GB |
| Full Fine-tune (BF16) | 14GB | 26GB | 140GB |
| LoRA (BF16) | 14GB | 26GB | 140GB |
| QLoRA (4-bit) | 6GB | 10GB | 48GB |
| QLoRA + Gradient Checkpointing | 4GB | 8GB | 40GB |
| DeepSpeed ZeRO-3 + LoRA | 8GB/GPU | 15GB/GPU | 60GB/GPU |

## LoRA Merging

```python
from peft import PeftModel

# Load base and adapter
base_model = AutoModelForCausalLM.from_pretrained("meta-llama/Llama-2-7b-hf")
peft_model = PeftModel.from_pretrained(base_model, "./lora_adapter")

# Merge weights
merged_model = peft_model.merge_and_unload()

# Save merged model
merged_model.save_pretrained("./merged_model")
```

## Determining Target Modules Automatically

```python
def find_all_linear_names(model):
    cls = torch.nn.Linear
    lora_module_names = set()
    for name, module in model.named_modules():
        if isinstance(module, cls):
            names = name.split('.')
            lora_module_names.add(names[0] if len(names) == 1 else names[-1])

    if 'lm_head' in lora_module_names:
        lora_module_names.remove('lm_head')
    return list(lora_module_names)

target_modules = find_all_linear_names(model)
print(f"Detected target modules: {target_modules}")
```

## LoRA Hyperparameter Tuning

```python
# Grid search example
import itertools

r_values = [8, 16, 32]
alpha_values = [16, 32, 64]
dropout_values = [0.0, 0.05, 0.1]

for r, alpha, dropout in itertools.product(r_values, alpha_values, dropout_values):
    config = LoraConfig(
        r=r,
        lora_alpha=alpha,
        lora_dropout=dropout,
        target_modules=["q_proj", "v_proj"],
    )
    # Run training experiment...
```
