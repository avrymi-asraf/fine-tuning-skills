# TinyLoRA: A 13-Parameter Fine-Tuning Method That Reaches 91.8% GSM8K on Qwen2.5-7B

**Authors:** FAIR at Meta, Cornell University, Carnegie Mellon University  
**Published:** March 2026 (MarkTechPost coverage)  
**arXiv:** 2602.04118  
**URL:** https://www.marktechpost.com/2026/03/24/this-ai-paper-introduces-tinylora-a-13-parameter-fine-tuning-method-that-reaches-91-8-percent-gsm8k-on-qwen2-5-7b/

## Core Finding

Large language models can learn to reason using a remarkably small number of trained parameters. Using TinyLoRA on a Qwen2.5-7B-Instruct backbone, the researchers achieved **91.8% accuracy on GSM8K with only 13 parameters** (26 bytes in bf16).

## How TinyLoRA Works

Standard LoRA adapts a frozen linear layer W ∈ R^{d×k} using trainable matrices A ∈ R^{d×r} and B ∈ R^{r×k}. The trainable parameter count still scales with layer width and rank, leaving a nontrivial lower bound even at rank 1. For Llama3-8B, this minimum is ~3 million parameters.

TinyLoRA builds on LoRA-XS (which uses truncated SVD of frozen weights) and replaces the trainable matrix with a **low-dimensional trainable vector v ∈ R^u** projected through a fixed random tensor P ∈ R^{u×r×r}.

**Update rule:**
W' = W + UΣ(Σᵢ vᵢPᵢ)Vᵀ

By applying weight tying (n_tie), total trainable parameters scale as O(nm·u/n_tie), allowing updates to scale down to a **single parameter** when all modules across all layers share the same vector.

## The RL Advantage

A core finding: **RL is fundamentally more efficient than SFT at extremely low parameter counts.** Models trained via SFT require updates 100–1,000x larger to reach the same performance as RL (specifically GRPO).

This is attributed to "information density":
- **SFT** forces the model to absorb many bits including stylistic noise and irrelevant structures (all tokens treated as equally informative)
- **RL** (GRPO) provides sparser but cleaner signal — rewards are binary (e.g., exact match for math answer), reward-relevant features correlate with signal while irrelevant variations cancel out through resampling

## Optimization Guidelines

- **Optimal frozen rank:** r=2 was optimal. Higher ranks introduced too many degrees of freedom for the small trainable vector
- **Tiling vs structured sharing:** "Tiling" (nearby modules of similar depth share parameters) was more effective than "structured" sharing (same module type share parameters)
- **Precision:** In bit-constrained regimes, fp32 proved most bit-efficient even accounting for larger footprint vs bf16/fp16

## Benchmark Results

| Model | Parameters Trained | GSM8K Pass@1 |
|-------|-------------------|---------------|
| Qwen2.5-7B-Instruct (Base) | 0 | 88.2% |
| Qwen2.5-7B-Instruct | 1 | 82.0% |
| Qwen2.5-7B-Instruct | 13 | 91.8% |
| Qwen2.5-7B-Instruct | 196 | 92.2% |
| Qwen2.5-7B-Instruct (Full FT) | ~7.6 Billion | 91.7% |

On harder benchmarks (MATH500, AIME24), 196-parameter updates retained 87% of the absolute performance improvement of full finetuning across six difficult math benchmarks.

## Scaling Insight

As models grow larger, they become more "programmable" with fewer absolute parameters — suggesting trillion-scale models could potentially be tuned for complex tasks using just a handful of bytes.

## Citation

```bibtex
@misc{tinylora2026,
  title={TinyLoRA},
  author={FAIR at Meta and Cornell University and Carnegie Mellon University},
  howpublished={arXiv:2602.04118},
  year={2026}
}
```