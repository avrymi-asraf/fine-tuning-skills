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

## LoRA Variants for Extreme Efficiency

- **TinyLoRA** ([[2026-tinylora-extreme-parameter-efficiency|Source]]): Scales LoRA down to 13 parameters using weight tying + random projections. Optimal frozen SVD rank r=2; tiling > structured sharing; RL (GRPO) >> SFT at low param counts.
- **LoRA-XS**: Uses truncated SVD of frozen weights as basis for updates. TinyLoRA builds on this.

## Practical Guidance

From [[2026-efficient-strategy-finetuning-frontiers|Frontiers 2026]]: alpha-to-rank ratio of **4:1** provides consistent balance of performance and compute. DSS + LoRA is the best performance-efficiency tradeoff under resource constraints.

## Sources

- [[sources/few-shot-parameter-efficient-fine-tuning-is-better|Few-Shot Parameter-Efficient Fine-Tuning is Better]]
- [[sources/2026-tinylora-extreme-parameter-efficiency|TinyLoRA]]
- [[sources/2026-efficient-strategy-finetuning-frontiers|DSS + LoRA/QLoRA Strategy]]

## See Also

- [[concepts/parameter-efficient-fine-tuning|PEFT]]
- [[concepts/qlora|QLoRA]]
- [[concepts/rl-based-finetuning|RL-Based Fine-Tuning]]
- [[concepts/catastrophic-forgetting-mitigation|Catastrophic Forgetting Mitigation]]