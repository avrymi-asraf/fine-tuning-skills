---
title: QLoRA (Quantized LoRA)
date_created: 2026-04-11
tags: [fine-tuning, QLoRA, quantization, PEFT, memory-efficient]
---

# QLoRA (Quantized LoRA)

> Quantized Low-Rank Adaptation for fine-tuning massive models on consumer hardware.

## Overview

QLoRA combines 4-bit quantization with LoRA to enable fine-tuning of very large language models (65B+ parameters) on single consumer GPUs with limited VRAM (e.g., 48GB).

## Key Innovations

### 4-bit Normal Float (NF4)
- Information-theoretically optimal quantization for normal distributions
- Better than standard 4-bit integer quantization

### Double Quantization
- Quantizes the quantization constants themselves
- Additional memory savings (~0.37 bits per parameter)

### Paged Optimizers
- Uses NVIDIA unified memory to handle memory spikes
- Automatically pages optimizer states to CPU RAM

## Memory Requirements (approximate)

- 7B model: ~6GB (vs ~28GB full fine-tuning)
- 13B model: ~10GB (vs ~52GB)
- 30B model: ~20GB (vs ~120GB)
- 65B model: ~40GB (vs ~260GB)

## Trade-offs

- Slightly slower training due to quantization/dequantization
- Minimal quality degradation compared to 16-bit LoRA
- Massive memory savings enable larger models

## Practical Guidance

From [[2026-efficient-strategy-finetuning-frontiers|Frontiers 2026]]: DSS + QLoRA enables training under tightest GPU memory budgets while maintaining competitive performance. Alpha-to-rank ratio of **4:1** recommended.

## Composability with MFT

[[2025-minifinetuning-corrective-self-distillation|MiniFineTuning]] is composable with QLoRA for combined benefits: MFT reduces degeneralization, QLoRA reduces memory requirements.

## Sources

- [[sources/few-shot-parameter-efficient-fine-tuning-is-better|Few-Shot Parameter-Efficient Fine-Tuning is Better]]
- [[sources/2026-efficient-strategy-finetuning-frontiers|DSS + LoRA/QLoRA Strategy]]
- [[sources/2025-minifinetuning-corrective-self-distillation|MiniFineTuning]]

## See Also

- [[concepts/lora|LoRA]]
- [[concepts/parameter-efficient-fine-tuning|PEFT]]
- [[concepts/catastrophic-forgetting-mitigation|Catastrophic Forgetting Mitigation]]