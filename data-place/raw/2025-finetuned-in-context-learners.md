# Fine-Tuned In-Context Learners for Efficient Adaptation

**Authors:** Jorg Bornschein (Google DeepMind), Clare Lyle (Google DeepMind), Yazhe Li (Microsoft AI), Amal Rannen-Triki (Google DeepMind), Xu Owen He (MakerMaker AI), Razvan Pascanu (Google DeepMind)  
**Published:** December 2025  
**arXiv:** 2512.19879  
**URL:** https://arxi v.org/abs/2512.19879

## Abstract

When adapting LLMs to a specific downstream task, two primary approaches are commonly employed:
1. **Prompt engineering / in-context few-shot learning** — leverages the model's inherent generalization abilities
2. **Fine-tuning on task-specific data** — directly optimizes the model's parameters

**The problem:** Prompt-based methods excel in few-shot scenarios but their effectiveness plateaus as more data becomes available. Fine-tuning scales well with data but may underperform when training examples are scarce.

## Proposed Solution: Fine-Tuned In-Context Learners

The authors investigate a **unified approach** that bridges the two paradigms by incorporating in-context learning directly into the fine-tuning process:

- Fine-tune the model on task-specific data **augmented with in-context examples**, mimicking the structure of k-shot prompts
- This combines the **sample efficiency of in-context learning** with the **performance gains of fine-tuning**
- The approach consistently matches and often significantly exceeds both baselines

## Hyperparameter Selection: Prequential Evaluation

In the low-data regime, the authors propose **prequential evaluation** for hyperparameter selection:
- Eliminates the need for expensive cross-validation
- Leverages all available data for training while simultaneously providing a robust validation signal
- Particularly valuable when data is too scarce to split into train/val/test

## Key Findings

- The unified approach bridges the gap between ICL and fine-tuning performance
- Sample efficiency of ICL is preserved while gaining the scalability of fine-tuning
- Prequential evaluation is a practical solution for hyperparameter tuning when data is limited

## Citation

```bibtex
@article{bornschein2025finetuned,
  title={Fine-Tuned In-Context Learners for Efficient Adaptation},
  author={Bornschein, Jorg and Lyle, Clare and Li, Yazhe and Rannen-Triki, Amal and He, Xu Owen and Pascanu, Razvan},
  journal={arXiv preprint arXiv:2512.19879},
  year={2025}
}
```