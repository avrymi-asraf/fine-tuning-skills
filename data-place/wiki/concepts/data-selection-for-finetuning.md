---
tags: [data-selection, ICL, attention, training-free, efficiency]
date: 2026-04-13
---

# Data Selection for Fine-Tuning

Rather than generating more data, data selection focuses on identifying the most informative subset of existing data for fine-tuning. This is especially valuable when computational budgets are limited or when data quality varies.

## Approaches

### Training-Free Methods
- **Data Whisperer** ([[2025-data-whisperer-efficient-data-selection|Source]]): Uses few-shot ICL with the target model + attention-based scoring to select data. No additional model training needed. Achieves better performance than full-dataset training with just 10% of data (7.4× speedup on GSM8K with Llama-3-8B-Instruct).

### Training-Based Methods
- Traditional approaches require fine-tuning a scoring model on the target dataset — time-consuming and resource-intensive
- Heuristic-based methods often fail to leverage the model's predictive capabilities

## Key Insight

For low-data scenarios, training-free selection methods are critical because:
1. You can't afford to split data for a separate scoring model
2. Every example matters — selecting the right 10% can outperform using 100%
3. The model itself (via ICL) can evaluate data quality without additional training

## Complementary With

- [[concepts/synthetic-data-generation|Synthetic Data Generation]] — Generate data, then select the best subset
- [[concepts/parameter-efficient-fine-tuning|PEFT]] — Fewer training examples + fewer parameters = maximal efficiency
- [[2025-finetuned-in-context-learners|Fine-Tuned ICL]] — ICL augmented training also leverages ICL for efficiency