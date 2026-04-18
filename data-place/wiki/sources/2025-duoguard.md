---
title: "DuoGuard: A Collaborative Two-Player Framework for Multilingual LLM Guardrails"
date: 2025-02-07
source_url: https://arxiv.org/abs/2502.05163
github_url: https://github.com/yihedeng9/DuoGuard
tags: [fine-tuning, RL, guardrails, multilingual, safety, adversarial-training, two-player-game]
---

# DuoGuard: A Collaborative Two-Player Framework for Multilingual LLM Guardrails

## Summary

DuoGuard introduces a **two-player, reinforcement-learning-driven framework** for training multilingual safety guardrails for large language models. Instead of relying on a single monolithic safety model, DuoGuard splits the guardrail task into two collaborative agents: a **Defender** and an **Attacker**. The Defender is trained to detect harmful content, while the Attacker is trained to generate adversarial synthetic prompts that challenge the Defender. This adversarial dynamic, formalized as a two-player game, continuously improves both players and results in a highly robust safety system.

## Key Contributions

- **Two-Player RL Framework**: Treats safety guardrail training as a collaborative game between a Defender (detector) and an Attacker (adversarial prompt generator).
- **Adversarial Synthetic Data Generation**: The Attacker generates challenging multilingual prompts on the fly, providing a continuous stream of hard training examples for the Defender.
- **Extreme Parameter Efficiency**: The final DuoGuard model is only **0.5B parameters**, yet it outperforms the much larger **Llama Guard 3 (8B)** on multilingual safety benchmarks.
- **Multilingual Capability**: The framework is explicitly designed to handle safety across multiple languages, addressing a common weakness in English-centric guardrail models.

## Methodology

1. **Defender Model**: A classification-style LLM fine-tuned to label prompts as safe or unsafe across multiple harm categories and languages.
2. **Attacker Model**: An LLM fine-tuned to generate adversarial prompts that are semantically harmful but designed to evade the Defender's detection.
3. **Two-Player RL Loop**:
   - The Attacker generates synthetic adversarial prompts.
   - The Defender is trained on these prompts (plus real harmful data) to improve detection.
   - As the Defender improves, the Attacker is updated to generate even harder examples.
   - This creates a self-improving curriculum without requiring new human-labeled data.

## Results

- **DuoGuard (0.5B)** consistently outperforms **Llama Guard 3 (8B)** on multilingual safety benchmarks.
- The two-player approach produces a more robust guardrail that is less susceptible to jailbreaks and adversarial perturbations compared to standard single-model safety classifiers.
- The method demonstrates that **reinforcement-learning-driven synthetic data generation** can close the performance gap between tiny specialized models and large generalist models.

## Implications for Fine-Tuning

- **RL for Data Augmentation**: DuoGuard is a strong example of using reinforcement learning not just to optimize a policy, but to generate a curriculum of hard training examples.
- **Small Models Can Outperform Large Ones**: With the right training data and adversarial objectives, a 0.5B model can surpass an 8B model on a specialized task.
- **Multilingual Safety**: The work highlights the importance of training guardrails (and by extension, fine-tuning datasets) that are not English-centric.

## Related Wiki Pages

- [[rl-based-finetuning]] — DuoGuard applies RL principles in a two-player game setting for safety guardrails.
- [[synthetic-data-generation]] — The Attacker generates adversarial synthetic data to harden the Defender.
- [[parameter-efficient-fine-tuning]] — The success of a 0.5B model suggests that extreme parameter efficiency is viable when paired with high-quality, task-specific training signals.
- [[2025-sft-memorizes-rl-generalizes]] — Another recent paper showing RL's advantages over pure supervised fine-tuning.
- [[2025-visual-rft]] and [[2025-visual-arft]] — Related works applying RL fine-tuning to vision-language models.

## Citation

```bibtex
@article{deng2025duoguard,
  title={DuoGuard: A Collaborative Two-Player Framework for Multilingual LLM Guardrails},
  author={Deng, Yihe and others},
  journal={arXiv preprint arXiv:2502.05163},
  year={2025}
}
```
