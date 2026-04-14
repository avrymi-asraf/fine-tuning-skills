# Few-Shot Fine-Tuning: Train a Model with 10 Examples

**Source:** distil labs  
**Published:** March 9, 2025  
**URL:** https://www.distillabs.ai/learn/few-shot-fine-tuning-train-model-with-10-examples

## Overview

Few-shot fine-tuning adapts a pre-trained language model using a very small labeled dataset — often between 5 and 50 examples. Unlike traditional fine-tuning that assumes hundreds or thousands of training samples, few-shot fine-tuning leverages the knowledge already embedded in the base model and nudges it toward a specific task with minimal data.

This approach works especially well with modern small language models (SLMs) like Llama 3.2 1B, Qwen3 0.6B, and Gemma 3 1B, which have been pre-trained on broad, diverse corpora.

## Few-Shot Fine-Tuning vs In-Context Learning

| Aspect | In-Context Learning | Few-Shot Fine-Tuning |
|--------|-------------------|---------------------|
| Examples at inference | Yes (in every prompt) | No |
| Latency | Higher (longer prompts) | Lower (no examples in prompt) |
| Cost per request | Higher (more tokens) | Lower (smaller model, shorter prompts) |
| Consistency | Variable | High |
| Privacy | Data sent to API | Runs locally |
| Setup effort | Minimal | Requires training step |

**Key insight:** In-context learning is great for prototyping, but few-shot fine-tuning is better for production. Once you've validated that a task is solvable with a few examples, fine-tuning locks in that performance permanently.

## How It Works with Synthetic Data

The secret to making few-shot fine-tuning work reliably is synthetic data generation:

1. **Seed examples** — Provide as few as 10 labeled examples that represent your task
2. **Generate synthetic training data** — A teacher model (like Llama 3.3 70B) uses your seed examples to generate hundreds or thousands of diverse, high-quality training samples
3. **Fine-tune the student model** — A small language model is fine-tuned on the synthetic dataset using LoRA or full fine-tuning
4. **Evaluate** — The fine-tuned student is benchmarked against the teacher to verify quality

## When Few-Shot Fine-Tuning Outperforms Prompting

- **Structured output tasks** — Classification, NER, information extraction, tool calling
- **High-volume inference** — Thousands of predictions per hour; cost savings compound
- **Latency-sensitive applications** — 1B parameter model responds 10–50x faster than 70B model via API
- **Privacy-constrained environments** — Healthcare, finance, government where data cannot leave infrastructure
- **Edge deployment** — Running models on devices, on-prem servers, or air-gapped environments

## Related

- [Small Expert Agents from 10 Examples](https://www.distillabs.ai/blog/small-expert-agents-from-10-examples)
- [Vibe-Tuning: Fine-Tuning SLMs with a Prompt](https://www.distillabs.ai/blog/vibe-tuning-the-art-of-fine-tuning-small-language-models-with-a-prompt)