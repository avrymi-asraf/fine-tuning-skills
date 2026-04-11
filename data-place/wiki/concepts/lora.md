---
title: LoRA (Low-Rank Adaptation)
date_created: 2026-04-11
tags: [fine-tuning, LoRA, PEFT, low-rank]
---

# LoRA (Low-Rank Adaptation)

> Low-rank adaptation for efficient fine-tuning of large language models.

## Overview

LoRA is a parameter-efficient fine-tuning method that injects trainable low-rank matrices into transformer layers. Instead of updating full weight matrices, LoRA learns low-rank decomposition matrices that are added to frozen pre-trained weights.

## How It Works

For a pre-trained weight matrix W₀, LoRA modifies the forward pass:

```
h = W₀x + ΔWx = W₀x + BAx
```

Where:
- W₀: Frozen pre-trained weights (d × k)
- B: Trainable matrix (d × r)
- A: Trainable matrix (r × k)
- r << min(d, k): Low rank

## Key Hyperparameters

- **r (rank)**: 4-128 — Rank of low-rank matrices
- **lora_alpha**: 8-256 — Scaling factor (often 2× rank)
- **lora_dropout**: 0.0-0.1 — Regularization
- **target_modules**: Which layers to adapt

## Advantages

1. **Memory Efficient**: Train 0.1-1% of parameters
2. **Storage**: Only save small adapter weights per task
3. **No Inference Latency**: Merge adapters into base model
4. **Modular**: Switch adapters for different tasks

## Sources

- [[sources/few-shot-parameter-efficient-fine-tuning-is-better|Few-Shot Parameter-Efficient Fine-Tuning is Better]]

## See Also

- [[concepts/parameter-efficient-fine-tuning|PEFT]]
- [[concepts/qlora|QLoRA]]