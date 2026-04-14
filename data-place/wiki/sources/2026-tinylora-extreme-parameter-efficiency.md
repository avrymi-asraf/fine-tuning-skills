---
tags: [LoRA, extreme-efficiency, RL, GRPO, weight-tying, math-reasoning]
date: 2026-04-13
sources: 1
---

# TinyLoRA: 13-Parameter Fine-Tuning Reaching 91.8% GSM8K

**Source:** [[2026-tinylora-extreme-parameter-efficiency]] | FAIR Meta/Cornell/CMU | arXiv:2602.04118

## Summary

Demonstrates that LLMs can learn reasoning with remarkably few trainable parameters. TinyLoRA uses a low-dimensional vector projected through a fixed random tensor, with weight tying allowing scaling down to a single parameter. RL (GRPO) is 100-1000x more parameter-efficient than SFT at low parameter counts.

## Key Takeaways

- **13 parameters (26 bytes) → 91.8% GSM8K** on Qwen2.5-7B-Instruct
- RL (GRPO) vastly outperforms SFT in extreme low-parameter regimes due to cleaner information density
- Optimal frozen SVD rank: r=2; tiling > structured sharing; fp32 > half-precision bit-for-bit
- Larger models become more "programmable" with fewer absolute parameters

## Connections

- Extreme extension of [[concepts/lora|LoRA]] — pushes parameter efficiency to its limit
- RL efficiency finding challenges the SFT-dominant paradigm in [[concepts/parameter-efficient-fine-tuning|PEFT]]
- Weight tying approach is conceptually related to parameter sharing in [[2025-optimization-inspired-few-shot-adaptation|OFA]]