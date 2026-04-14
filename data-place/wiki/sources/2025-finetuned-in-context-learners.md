---
tags: [in-context-learning, fine-tuning, prequential-evaluation, unified-adaptation]
date: 2026-04-13
sources: 1
---

# Fine-Tuned In-Context Learners for Efficient Adaptation

**Source:** [[2025-finetuned-in-context-learners]] | Google DeepMind/Microsoft | arXiv:2512.19879

## Summary

Unifies ICL and fine-tuning by training on task-specific data augmented with in-context examples (mimicking k-shot prompts). Combines sample efficiency of ICL with scalability of fine-tuning. Proposes prequential evaluation for hyperparameter selection in low-data regimes.

## Key Takeaways

- **Unified approach** consistently matches or exceeds both ICL and fine-tuning baselines
- Training data augmented with k-shot prompt structure
- **Prequential evaluation** — eliminates need for cross-validation, uses all data for training while providing validation signal
- Particularly valuable when data is too scarce for train/val/test splits

## Connections

- Bridges the ICL vs fine-tuning debate discussed in [[2025-few-shot-fine-tuning-10-examples|distil labs article]]
- Prequential evaluation is a practical tool for any [[concepts/parameter-efficient-fine-tuning|PEFT]] approach
- ICL-augmented training complements [[2025-data-whisperer-efficient-data-selection|Data Whisperer]]'s ICL-based data selection