---
tags: [catastrophic-forgetting, domain-adaptation, self-distillation, generalization]
date: 2026-04-13
---

# Catastrophic Forgetting Mitigation

When fine-tuning on a new domain, models tend to lose capabilities on the original domain — this is catastrophic forgetting. The specialization-degeneralization trade-off is central to low-data fine-tuning.

## The Problem

- Fine-tuning inevitably leads to some deterioration of general performance
- The effect is **more pronounced** when data is limited (overfitting is easier)
- Traditional mitigation (replay) requires access to general-domain data, which isn't always available

## Mitigation Strategies

### Corrective Self-Distillation (MiniFineTuning)
([[2025-minifinetuning-corrective-self-distillation|Source]])

- Student trains on τ-corrected soft labels from the unfinetuned model (its own teacher)
- **9x lower degeneralization** than standard FT
- Works without replay data — critical when general-domain data is unavailable
- Composable with PEFT methods for compounding benefits
- Robust down to 500 samples

### PEFT Methods
([[2024-finetuning-llms-limited-data-survey|Survey]])

- By freezing most parameters, PEFT inherently reduces forgetting
- LoRA, QLoRA, adapters all limit the "damage" to base model capabilities
- Trade-off: too few trainable parameters → underfitting; too many → forgetting

### Data Selection
([[2025-data-whisperer-efficient-data-selection|Data Whisperer]])

- Selecting the right data reduces the amount of training needed, indirectly reducing forgetting
- 10% of well-selected data can outperform 100% of uncurated data

## Key Insight

The best strategies combine approaches:
- **MFT + LoRA/QLoRA** for compounding benefits
- **DSS + LoRA** for efficient data creation with controlled adaptation
- **Data selection + PEFT** for minimal training with maximal effect