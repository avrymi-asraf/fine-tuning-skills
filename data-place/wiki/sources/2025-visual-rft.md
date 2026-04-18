---
title: "Visual-RFT: Visual Reinforcement Fine-Tuning"
date: 2025-03-03
source_url: https://arxiv.org/abs/2503.01785
github_url: https://github.com/Liuziyu77/Visual-RFT
tags: [fine-tuning, RL, vision-language, VLM, GRPO, few-shot, object-detection, classification, ICCV-2025]
---

# Visual-RFT: Visual Reinforcement Fine-Tuning

## Summary

Visual-RFT extends the **DeepSeek-R1 style GRPO (Group Relative Policy Optimization)** reinforcement fine-tuning paradigm to **vision-language models (VLMs)**. The key insight is that verifiable rewards—such as Intersection over Union (IoU) for object detection or exact-match accuracy for fine-grained classification—can replace human preference labels, enabling highly sample-efficient RL fine-tuning on vision tasks. Visual-RFT demonstrates strong performance gains in **few-shot object detection**, **fine-grained visual classification**, and **visual reasoning** with minimal labeled data.

## Key Contributions

- **GRPO for VLMs**: Adapts the group-sampling and relative-reward mechanism of GRPO to multimodal settings, where the model generates reasoning traces and answers based on both image and text prompts.
- **Verifiable Rewards**: Uses task-specific, automatically computable rewards (e.g., IoU, accuracy) instead of learned reward models or human preferences, reducing the cost and complexity of RL fine-tuning.
- **Few-Shot Efficacy**: Shows substantial improvements over supervised fine-tuning (SFT) baselines when only a handful of labeled examples are available per class or task.
- **Broad Applicability**: Evaluated on object detection, fine-grained classification, and visual reasoning benchmarks.

## Methodology

1. **Model Architecture**: Applies to standard decoder-only VLMs (e.g., Qwen2-VL, InternVL) that process interleaved image and text tokens.
2. **GRPO Adaptation**:
   - For each training prompt (image + question), the model samples a group of candidate outputs (reasoning + answer).
   - A **verifiable reward function** scores each output based on the ground-truth label or bounding box.
   - The policy is updated to increase the likelihood of high-reward outputs relative to the group average.
3. **Reward Functions**:
   - **Detection**: IoU between predicted and ground-truth bounding boxes.
   - **Classification**: Exact-match or soft accuracy on the predicted class label.
   - **Reasoning**: Task-specific verifiers (e.g., counting correctness).

## Results

- **Few-Shot Object Detection**: Visual-RFT achieves large improvements over SFT baselines on standard detection datasets when trained with only a few examples per category.
- **Fine-Grained Classification**: Outperforms SFT on specialized visual classification tasks, suggesting that RL fine-tuning helps the model attend to subtle visual cues.
- **Data Efficiency**: Because rewards are verifiable and do not require human annotation beyond the ground truth, the method scales well to new tasks with minimal labeling.

## Implications for Fine-Tuning

- **RL Beyond Language**: Visual-RFT is one of the first works to successfully apply reasoning-time RL (à la DeepSeek-R1) to vision-language models, opening the door for RL fine-tuning in multimodal AI.
- **Verifiable Rewards Are Enough**: The work challenges the assumption that RLHF-style preference models are necessary for RL fine-tuning; hard, verifiable metrics can serve the same role in structured tasks.
- **Few-Shot Vision Learning**: The strong few-shot results suggest that RL fine-tuning may be a better inductive bias than SFT for learning from very small visual datasets.

## Related Wiki Pages

- [[rl-based-finetuning]] — Core concept page for RL fine-tuning; Visual-RFT is a major multimodal extension.
- [[parameter-efficient-fine-tuning]] — Visual-RFT can be combined with LoRA/QLoRA for efficient updates of large VLMs.
- [[synthetic-data-generation]] — Verifiable rewards reduce the need for large human-labeled preference datasets.
- [[2025-sft-memorizes-rl-generalizes]] — Complementary finding that RL generalizes better than SFT, now extended to the vision domain.
- [[2025-duoguard]] — Another recent RL fine-tuning paper using adversarial synthetic data.
- [[2025-visual-arft]] — Follow-up work extending Visual-RFT to agentic vision-language tasks.

## Citation

```bibtex
@article{liu2025visualrft,
  title={Visual-RFT: Visual Reinforcement Fine-Tuning},
  author={Liu, Ziyu and others},
  journal={arXiv preprint arXiv:2503.01785},
  year={2025}
}
```
