---
title: Parameter-Efficient Fine-Tuning (PEFT)
date_created: 2026-04-11
tags: [fine-tuning, PEFT, efficiency, LLM-training]
---

# Parameter-Efficient Fine-Tuning (PEFT)

> Techniques for fine-tuning large language models by updating only a small subset of parameters.

## Overview

Parameter-Efficient Fine-Tuning (PEFT) refers to methods that adapt large pre-trained language models to downstream tasks without updating all model parameters. This approach dramatically reduces memory requirements and training time while maintaining competitive performance.

## Key Methods

### LoRA (Low-Rank Adaptation)
- Adds low-rank matrices to weight matrices in attention layers
- Typically trains <1% of original parameters
- Configurable rank (r) and scaling (alpha) parameters

### QLoRA (Quantized LoRA)
- Combines LoRA with 4-bit quantization
- Enables fine-tuning 65B+ models on single consumer GPU
- Uses NF4 quantization and double quantization

### Adapters
- Small neural networks inserted between transformer layers
- Original model weights frozen
- Only adapter parameters trained

### Prefix Tuning
- Prepends learnable vectors to input embeddings
- Freezes all original model parameters
- Lightweight alternative to full fine-tuning

## Benefits

- **Trainable Parameters**: 0.1-1% vs 100% for full fine-tuning
- **Memory Required**: Low vs High
- **Storage per Task**: Small adapters vs full model
- **Catastrophic Forgetting**: Minimal vs significant

## Extreme PEFT: TinyLoRA

[[2026-tinylora-extreme-parameter-efficiency|TinyLoRA]] pushes PEFT to its limit — achieving 91.8% GSM8K with only 13 trainable parameters on Qwen2.5-7B. Uses weight tying + random projections, and finds RL (GRPO) is 100-1000x more efficient than SFT at low parameter counts.

## PEFT for Few-Shot Adaptation

[[2025-optimization-inspired-few-shot-adaptation|OFA]] takes a different approach: uses LayerNorm as learnable preconditioners without adding parameters, avoiding PEFT's overfitting risk on few-shot data.

## Sources

- [[sources/few-shot-parameter-efficient-fine-tuning-is-better|Few-Shot Parameter-Efficient Fine-Tuning is Better]]
- [[sources/few-shot-fine-tuning-techniques-overview|Few-Shot Fine-Tuning Techniques Overview]]
- [[sources/2024-finetuning-llms-limited-data-survey|Fine-tuning LLMs with Limited Data: Survey]]
- [[sources/2026-tinylora-extreme-parameter-efficiency|TinyLoRA]]
- [[sources/2025-optimization-inspired-few-shot-adaptation|OFA]]

## See Also

- [[concepts/lora|LoRA]]
- [[concepts/qlora|QLoRA]]
- [[concepts/catastrophic-forgetting-mitigation|Catastrophic Forgetting Mitigation]]
- [[concepts/rl-based-finetuning|RL-Based Fine-Tuning]]