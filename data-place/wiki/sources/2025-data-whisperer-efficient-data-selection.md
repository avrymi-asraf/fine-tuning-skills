---
tags: [data-selection, ICL, attention, training-free, efficient-finetuning]
date: 2026-04-13
sources: 1
---

# Data Whisperer: Efficient Data Selection for Task-Specific LLM Fine-Tuning

**Source:** [[2025-data-whisperer-efficient-data-selection]] | ACL 2025 | arXiv:2505.12212

## Summary

Training-free, attention-based method that uses few-shot ICL with the target model to select the most informative training data. Achieves better performance than full-dataset training using just 10% of data, with 7.4× speedup.

## Key Takeaways

- **10% of data outperforms 100%** on GSM8K with Llama-3-8B-Instruct
- Training-free: no separate scoring model needed
- Uses model's own attention patterns + ICL to evaluate data quality
- 3.1-point improvement over existing methods

## Connections

- Data selection is complementary to [[concepts/parameter-efficient-fine-tuning|PEFT]] methods
- Relevant when combining with [[2025-few-shot-fine-tuning-10-examples|synthetic data approaches]]
- ICL-based selection connects to [[2025-finetuned-in-context-learners|Fine-Tuned ICL]] approach