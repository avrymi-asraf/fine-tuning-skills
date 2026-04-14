# Optimization-Inspired Few-Shot Adaptation for Large Language Models (OFA)

**Authors:** Boyan Gao (Oxford), Xin Wang (Oxford), Yibo Yang (KAUST), David Clifton (Oxford)  
**Published:** May 2025  
**arXiv:** 2505.19107  
**URL:** https://arxiv.org/abs/2505.19107

## Abstract

Adapting LLMs to novel tasks via fine-tuning often requires substantial training data and computational resources that are impractical in few-shot scenarios. Existing approaches face key limitations:

- **In-context learning (ICL):** Introduces additional inference computational overhead with limited performance gains
- **PEFT:** Prone to overfitting on the few demonstration examples

OFA reinterprets the **forward pass of LLMs as an optimization process** — a sequence of preconditioned gradient descent steps refining internal representations. Based on this connection, it proposes:

1. A parameterization that learns **preconditioners without introducing additional trainable parameters** (using LayerNorm layers)
2. An objective that improves optimization efficiency by learning preconditioners based on a **convergence bound**
3. Steering the optimization path toward the **flat local minimum** for better generalization

## Key Innovation

The method treats LayerNorm layers as learnable preconditioning matrices in the LLM's forward pass, which:
- Introduces learnable parameters for adaptation
- Enables control of the few-shot adaptation process to **avoid overfitting**
- Does not add additional parameters beyond what already exists in the model

## Advantages Over Alternatives

- **vs ICL:** No extra inference cost from demonstration examples; actual parameter learning occurs
- **vs PEFT (LoRA etc.):** No overfitting to few-shot data; the preconditioner-based approach generalizes better
- Theoretical grounding: convergence bound provides principled optimization objective

## Results

Superior performance over existing methods on a variety of few-shot adaptation tasks.

## Citation

```bibtex
@article{gao2025ofa,
  title={Optimization-Inspired Few-Shot Adaptation for Large Language Models},
  author={Gao, Boyan and Wang, Xin and Yang, Yibo and Clifton, David},
  journal={arXiv preprint arXiv:2505.19107},
  year={2025}
}
```