# Fine-tuning Large Language Models with Limited Data: A Survey and Practical Guide

**Authors:** Marton Szep, Daniel Rueckert, Rüdiger von Eisenhart-Rothe, Florian Hinterwimmer  
**Institutions:** TU Munich, Imperial College London  
**Published:** November 2024 (revised October 2025), Accepted to TACL  
**URL:** https://arxiv.org/abs/2411.09539  
**arXiv:** 2411.09539

## Abstract

Fine-tuning large language models (LLMs) with limited data poses a practical challenge in low-resource languages, specialized domains, and constrained deployment settings. While pre-trained LLMs provide strong foundations, effective adaptation under data scarcity requires focused and efficient fine-tuning techniques. This paper presents a structured and practical survey of recent methods for fine-tuning LLMs in data-scarce scenarios. The authors systematically review:

1. **Parameter-efficient Fine-tuning (PEFT)** — techniques that lower training and deployment costs
2. **Domain and Cross-lingual FT** — adaptation methods for both encoder and decoder models
3. **Model Specialization** — strategies for specialized tasks, domains, and low-resource languages
4. **Preference Alignment** — approaches that guide model behavior using limited human or synthetic feedback

## Key Contributions

- Structured taxonomy of methods organized by PEFT composition types (selective, additive, low-rank)
- Empirical trade-offs and selection criteria for choosing techniques based on task constraints
- Coverage of model scaling, data scaling, and mitigation of catastrophic forgetting
- Practical guidance for low-data scenarios across medicine, law, chemistry, and finance domains

## PEFT Method Categories (Section 3)

### Parameter Composition
- **Selective methods:** Train only a subset of weights (specific layers, parameter types)
- **Additive methods:** Add new trainable parameters alongside frozen base weights (adapters, prefix-tuning, prompt-tuning)
- **Low-rank methods:** LoRA and variants decompose weight updates into low-rank matrices

### Key Findings
- PEFT mitigates computational cost, sample inefficiency, and instability of full fine-tuning in low-resource regimes
- PEFT reduces risk of catastrophic forgetting in data-scarce scenarios
- The survey provides comparative analysis of when each PEFT category is most appropriate

## Practical Takeaways

- When data is scarce, PEFT methods are strongly preferred over full fine-tuning
- Choice of PEFT method should depend on: available compute, data volume, domain specificity, and deployment constraints
- Cross-lingual transfer can be effective even with minimal target-language data
- Preference alignment with limited feedback requires careful sample and compute efficiency considerations

## Citation

```bibtex
@article{szep2024finetuning,
  title={Fine-tuning Large Language Models with Limited Data: A Survey and Practical Guide},
  author={Szep, Marton and Rueckert, Daniel and von Eisenhart-Rothe, R{\"u}diger and Hinterwimmer, Florian},
  journal={arXiv preprint arXiv:2411.09539},
  year={2024}
}
```