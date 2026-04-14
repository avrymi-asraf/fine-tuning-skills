---
tags: [few-shot, LayerNorm, preconditioning, overfitting-avoidance, convergence]
date: 2026-04-13
sources: 1
---

# Optimization-Inspired Few-Shot Adaptation (OFA)

**Source:** [[2025-optimization-inspired-few-shot-adaptation]] | Oxford/KAUST | arXiv:2505.19107

## Summary

Reinterprets the LLM forward pass as preconditioned gradient descent and uses LayerNorm layers as learnable preconditioners — no additional parameters required. Optimizes for convergence speed and flat minima to avoid overfitting on few-shot data.

## Key Takeaways

- **LayerNorm as preconditioner** — turns existing model parameters into adaptation levers without adding parameters
- Avoids both ICL's inference overhead and PEFT's overfitting problem
- Convergence-bound objective provides theoretical grounding
- Steering toward flat minima improves generalization from few examples

## Connections

- Novel perspective on [[concepts/parameter-efficient-fine-tuning|PEFT]] — uses existing parameters rather than adding new ones
- Complementary to [[concepts/lora|LoRA]] — could potentially be combined
- Addresses overfitting concern also tackled by [[2025-minifinetuning-corrective-self-distillation|MFT]]