---
tags: [domain-adaptation, self-distillation, catastrophic-forgetting, low-data, NVIDIA]
date: 2026-04-13
sources: 1
---

# MiniFineTuning: Low-Data Domain Adaptation via Corrective Self-Distillation

**Source:** [[2025-minifinetuning-corrective-self-distillation]] | NVIDIA Research | arXiv:2506.15702

## Summary

Corrective self-distillation method that individualizes training at token level. The student matches τ-corrected soft labels from the teacher (the unfinetuned model itself). Achieves 2-10x better specialization-to-degeneralization ratios than standard FT, robust down to 500 samples, no replay data needed.

## Key Takeaways

- **9x lower degeneralization** than standard FT across all data budgets
- Works with as few as 500 samples; intrinsic robustness to overfitting
- Composable with PEFT (LoRA, DoRA, IA3) and replay for compounding benefits
- Tunable τ parameter controls specialization vs general capability balance
- Being deployed in NVIDIA's enterprise NIMs and NIM microservices

## Connections

- Directly addresses catastrophic forgetting concern raised in [[2024-finetuning-llms-limited-data-survey|Limited Data Survey]]
- Composable with [[concepts/lora|LoRA]] and [[concepts/qlora|QLoRA]]
- Self-distillation approach contrasts with teacher-student in [[2025-few-shot-fine-tuning-10-examples|distil labs approach]]
- Overfitting avoidance parallels [[2025-optimization-inspired-few-shot-adaptation|OFA]]