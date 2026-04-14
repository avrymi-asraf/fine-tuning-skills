---
tags: [synthetic-data, teacher-student, data-augmentation, SLM]
date: 2026-04-13
---

# Synthetic Data Generation for Fine-Tuning

Synthetic data generation is a key technique for overcoming data scarcity in fine-tuning. A larger "teacher" model generates diverse, high-quality training samples from a small set of seed examples, which are then used to train a smaller "student" model.

## How It Works

1. **Seed examples** — As few as 10 labeled examples representing the task
2. **Teacher generation** — A large model (e.g., 70B params) generates hundreds/thousands of diverse training samples from the seeds
3. **Student fine-tuning** — A small model (e.g., 1B params) is fine-tuned on the synthetic data via LoRA or full fine-tuning
4. **Evaluation** — Student benchmarked against teacher to verify quality

## Variants

- **Distilling Step-by-Step (DSS):** Teacher generates both labels and intermediate rationales via Chain-of-Thought prompting. Rationale supervision consistently outperforms label-only training. ([[2026-efficient-strategy-finetuning-frontiers|Source]])
- **Standard synthetic generation:** Teacher generates task-parallel examples without rationales. Used by distil labs pipeline. ([[2025-few-shot-fine-tuning-10-examples|Source]])

## When to Use

- Data is too scarce for effective fine-tuning directly (under 50-100 examples)
- Need to train a compact model for production (latency, cost, privacy)
- A larger teacher model is available for generation

## Trade-offs

- Quality depends heavily on teacher model quality
- Synthetic data may not cover edge cases present in real data
- Risk of amplifying teacher model biases
- Generation cost can be significant for large datasets

## See Also

- [[concepts/parameter-efficient-fine-tuning|PEFT]] — Often combined with synthetic data for student fine-tuning
- [[concepts/lora|LoRA]] — Most common fine-tuning method for student models
- [[concepts/data-selection-for-finetuning|Data Selection]] — Complementary: select best data rather than generate more