---
title: "Visual-ARFT: Visual Agentic Reinforcement Fine-Tuning"
date: 2025-05-20
source_url: https://arxiv.org/abs/2505.14246
github_url: https://github.com/Liuziyu77/Visual-RFT
tags: [fine-tuning, RL, vision-language, VLM, agents, GRPO, tool-use, web-search, image-editing, code-generation]
---

# Visual-ARFT: Visual Agentic Reinforcement Fine-Tuning

## Summary

Visual-ARFT is a follow-up to [[2025-visual-rft|Visual-RFT]] that pushes reinforcement fine-tuning into the **agentic capabilities** of large vision-language models (LVLMs). Instead of limiting RL to static perception tasks (detection, classification), Visual-ARFT trains models to perform multi-step agentic tasks such as **web search**, **image manipulation via code**, and **visual tool use**. It retains the GRPO-based training and verifiable-reward philosophy of Visual-RFT, but designs reward functions that capture the correctness of agent trajectories and final outcomes.

## Key Contributions

- **Agentic RL Fine-Tuning for VLMs**: Extends GRPO-based reinforcement fine-tuning from passive perception to active, tool-using agents.
- **Verifiable Trajectory Rewards**: Defines reward functions that score not just final answers, but intermediate agent actions (e.g., correct API calls, successful image edits, accurate web retrieval).
- **Multi-Task Generalization**: Demonstrates improvements across web-search agents, visual programming agents, and embodied visual reasoning tasks.
- **Scalability**: Shows that relatively small amounts of agentic demonstration data, combined with RL, can unlock complex behaviors in off-the-shelf VLMs.

## Methodology

1. **Agentic Task Formulation**: Each task is framed as a partially observable Markov decision process (POMDP) where the VLM observes an image/text state and outputs an action (e.g., generate Python code to edit an image, or issue a search query).
2. **GRPO for Agents**:
   - The model samples a group of action trajectories for a given visual prompt.
   - A **verifiable reward function** evaluates each trajectory:
     - **Web search**: Did the agent retrieve the correct information?
     - **Image editing**: Does the executed code produce the desired visual output (measured by pixel-level or semantic similarity)?
     - **Tool use**: Were the correct tools invoked with valid arguments?
   - The policy is updated to favor high-reward trajectories relative to the group baseline.
3. **Rejection Sampling & Bootstrapping**: Successful trajectories are collected and can be used to warm-start the policy or generate synthetic training data for further rounds.

## Results

- **Web-Search Agents**: Visual-ARFT improves the accuracy of visual question answering that requires external knowledge retrieval.
- **Visual Programming**: The model becomes more reliable at generating executable code for image manipulation tasks.
- **Tool-Using Agents**: Demonstrates better grounding of visual inputs to correct API/tool invocations compared to SFT baselines.
- **Generalization**: The RL-trained agents show better out-of-distribution robustness when faced with novel visual inputs or unseen tool configurations.

## Implications for Fine-Tuning

- **RL Unlocks Agentic Behaviors**: Supervised fine-tuning alone often produces brittle agents that hallucinate tool calls; RL fine-tuning with verifiable rewards significantly improves reliability.
- **Reward Engineering for Agents**: Visual-ARFT highlights the importance of designing precise, automatically checkable reward functions for agent training—an active area of research sometimes called "reward hacking-resistant" design.
- **Multimodal + RL Convergence**: Together with Visual-RFT and DuoGuard, Visual-ARFT points to a broader trend: RL fine-tuning is expanding from text-only chat models to vision, safety, and agentic domains.

## Related Wiki Pages

- [[rl-based-finetuning]] — Central concept for all RL fine-tuning methods.
- [[2025-visual-rft]] — Direct predecessor applying GRPO to static vision tasks.
- [[2025-duoguard]] — Parallel work using RL in a two-player adversarial setting.
- [[2025-sft-memorizes-rl-generalizes]] — Foundational evidence that RL generalizes better than SFT, now extended to agentic vision tasks.
- [[parameter-efficient-fine-tuning]] — Agentic VLMs are large; PEFT methods are essential for making RL fine-tuning computationally feasible.
- [[synthetic-data-generation]] — Agentic trajectories can be bootstrapped and used as synthetic training data.

## Citation

```bibtex
@article{liu2025visualarft,
  title={Visual-ARFT: Visual Agentic Reinforcement Fine-Tuning},
  author={Liu, Ziyu and others},
  journal={arXiv preprint arXiv:2505.14246},
  year={2025}
}
```
