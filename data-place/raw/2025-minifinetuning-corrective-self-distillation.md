# MiniFineTuning: Low-Data Generation Domain Adaptation through Corrective Self-Distillation

**Authors:** Peter Belcak, Greg Heinrich, Jan Kautz, Pavlo Molchanov  
**Institution:** NVIDIA Research  
**Published:** 2025  
**arXiv:** 2506.15702  
**URL:** https://research.nvidia.com/labs/lpr/minifinetuning

## Abstract

Finetuning language models for a new domain inevitably leads to deterioration of general performance. This becomes more pronounced the more limited the finetuning data resource. MiniFineTuning (MFT) is a method for language model domain adaptation that **considerably reduces the effects of overfitting-induced degeneralization in low-data settings** without requiring any pre-training data for replay.

## Key Results

- **2-10x more favourable specialization-to-degeneralization ratios** than standard finetuning across a wide range of models and domains
- **Intrinsic robustness to overfitting** when data is scarce — down to as little as **500 samples**
- Outperforms parameter-efficient finetuning methods
- Demonstrates **replay-like degeneralization mitigation properties** without needing general-domain replay data
- **Composable** with PEFT methods (LoRA, DoRA, IA3) and replay for combined effect

## Method: Corrective Self-Distillation

MFT uses corrective self-distillation that is **individualized on the sample level**:

- The student model trains to match **corrected soft labels** of its own unfinetuned predictions (produced by the teacher)
- Only finetuning data is used — pre-training general domain data is **not necessary**
- The teacher's predictions are customized on a per-token basis via τ-correction for the student's learning
- A tunable correction parameter (τ) governs how much weight is given to domain-specific labels vs the original model's predictions

## Specialization-Degeneralization Dynamics

Key finding: MFT exhibits **nine-fold lower levels of degeneralization** consistently across all data budgets compared to standard finetuning. This means models keep their general capabilities while still specializing.

## Enterprise Deployment

MFT is seeing deployment experimentation in NVIDIA's enterprise NIMs and NIM microservices:
- **Robust low-data domain adaptation without pretraining replay** — ideal for proprietary domains with limited data
- **Operational efficiency** — compatible with LoRA, DoRA, IA3, and replay
- **Tunable specialization** — τ parameter allows different balances between domain fidelity and general-purpose skills

## Comparison with Other Methods

- **vs DoRA:** MFT displays clearly more favourable specialization-to-degeneralization trade-offs across all ranks
- **vs Replay:** Replay exhibits slightly better trade-off but requires general domain data (not always available). MFT competes without needing that data.
- **vs Standard FT:** 2-10x improvement in specialization-to-degeneralization ratio

## Citation

```bibtex
@techreport{belcak2025minifinetuning,
  title = {Minifinetuning: Low-Data Generation Domain Adaptation through Corrective Self-Distillation},
  author = {Belcak, Peter and Heinrich, Greg and Kautz, Jan and Molchanov, Pavlo},
  institution = {NVIDIA Research},
  year = {2025},
  type = {NVIDIA Technical Report},
  number = {arXiv:2506.15702}
}
```