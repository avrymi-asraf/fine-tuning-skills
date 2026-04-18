---
tags: [SFT, RL, generalization, memorization, post-training, multi-modal, ICML-2025]
date: 2026-04-14
sources: 1
---

# SFT Memorizes, RL Generalizes: A Comparative Study of Foundation Model Post-training

**Source:** [[2025-sft-memorizes-rl-generalizes]] | HKU / UC Berkeley / Google DeepMind / NYU / University of Alberta | arXiv:2501.17161 | ICML 2025

## Summary

A large-scale comparative study of supervised fine-tuning (SFT) versus reinforcement learning (RL) for foundation model post-training. The authors introduce two evaluation benchmarks—GeneralPoints (arithmetic reasoning card game) and V-IRL (real-world visual navigation)—to measure generalization to unseen textual rule variants and visual out-of-distribution scenarios. RL with outcome-based rewards generalizes significantly better than SFT, which tends to memorize training data. Surprisingly, RL also improves underlying visual recognition capabilities. However, SFT remains essential as a warmup to stabilize output formats before RL.

## Key Takeaways

- **RL generalizes; SFT memorizes**: Across both textual rule variants and visual OOD settings, RL-trained models generalize while SFT-trained models overfit.
- **Outcome-based rewards are key**: RL generalization is strongest when trained with binary/outcome-based rewards rather than process-based rewards.
- **RL improves visual recognition**: Scaling post-training compute under RL improves both recognition accuracy and overall success rate, while SFT shows the opposite trend.
- **SFT is still essential**: SFT stabilizes the model's output format and serves as an effective warmup before RL training.
- **Verification amplifies generalization**: Sequential verification-revision during RL training further accelerates OOD performance gains.

## Evaluation Tasks

### GeneralPoints
- Arithmetic reasoning card game where the goal is to create an equation equal to 24 using all 4 numbers from dealt cards exactly once.
- Rule variants: switch the interpretation of J, Q, K.
- Visual variants: change card colors (black suits → red suits).

### V-IRL
- Real-world visual navigation environment.
- Rule variants: switch the textual action space.
- Visual variants: evaluate on routes from different cities worldwide.
- As a byproduct, achieves state-of-the-art on the V-IRL VLN mini benchmark.

## Connections

- Reinforces the RL >> SFT finding in extreme low-parameter regimes from [[2026-tinylora-extreme-parameter-efficiency|TinyLoRA]].
- Provides empirical grounding for the rise of RL-based fine-tuning discussed in [[concepts/rl-based-finetuning|RL-Based Fine-Tuning]].
- SFT-as-warmup insight aligns with practical pipelines using DSS + LoRA/QLoRA ([[2026-efficient-strategy-finetuning-frontiers|Frontiers 2026]]) where SFT precedes RL stages.
