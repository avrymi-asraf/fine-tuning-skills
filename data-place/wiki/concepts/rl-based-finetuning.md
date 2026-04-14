---
tags: [RL, GRPO, SFT-vs-RL, parameter-efficiency, math-reasoning]
date: 2026-04-13
---

# RL-Based Fine-Tuning

Reinforcement learning (specifically GRPO — Group Relative Policy Optimization) is emerging as a powerful alternative to supervised fine-tuning (SFT), particularly in extreme low-parameter regimes.

## Key Finding: RL vs SFT Efficiency

From [[2026-tinylora-extreme-parameter-efficiency|TinyLoRA]]:

> Models trained via SFT require updates **100–1,000x larger** to reach the same performance as RL at low parameter counts.

### Why RL Is More Efficient

- **Information density:** SFT forces the model to absorb many bits of information including stylistic noise and irrelevant structures (all tokens treated equally). RL provides sparser but cleaner signal.
- **Reward signal:** Binary rewards (e.g., exact match for math answer) mean reward-relevant features correlate with the signal while irrelevant variations cancel out through resampling.
- **Less noise absorption:** RL doesn't force the model to mimic demonstration style, only to achieve correct outcomes.

## Practical Implications

- For extreme parameter efficiency (sub-100 parameters), RL dominates SFT
- As parameter budget increases, the gap narrows
- Combining RL with [[concepts/lora|LoRA]] or [[2026-tinylora-extreme-parameter-efficiency|TinyLoRA]] is particularly effective
- Most impactful for reasoning tasks with verifiable answers (math, code, logic)

## Open Questions

- How does RL efficiency scale with task complexity beyond math/reasoning?
- What about tasks where rewards aren't easily verifiable?
- Interaction effects between RL, PEFT methods, and data augmentation

## See Also

- [[concepts/parameter-efficient-fine-tuning|PEFT]] — The parameter efficiency that makes RL viable with tiny updates
- [[2026-tinylora-extreme-parameter-efficiency|TinyLoRA]] — The paper that demonstrated RL's extreme efficiency advantage