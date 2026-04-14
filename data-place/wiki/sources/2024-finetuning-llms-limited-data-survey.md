---
tags: [survey, PEFT, domain-adaptation, low-resource, preference-alignment]
date: 2026-04-13
sources: 1
---

# Fine-tuning LLMs with Limited Data: A Survey and Practical Guide

**Source:** [[2024-finetuning-llms-limited-data-survey]] | arXiv:2411.09539 | TACL 2024/2025

## Summary

The most comprehensive survey to date on fine-tuning LLMs when data is scarce. Covers four key areas: PEFT methods, domain/cross-lingual adaptation, model specialization, and preference alignment. Provides actionable selection criteria based on task constraints.

## Key Takeaways

- PEFT is strongly preferred over full fine-tuning in low-data regimes (lower cost, reduced catastrophic forgetting)
- PEFT methods organized by composition: **selective** (train subset of weights), **additive** (adapters, prefix-tuning), **low-rank** (LoRA and variants)
- Cross-lingual transfer can work even with minimal target-language data
- Preference alignment requires careful sample/compute efficiency when feedback is limited

## Connections

- Provides the theoretical backbone for [[concepts/parameter-efficient-fine-tuning|PEFT]]
- Context for [[concepts/lora|LoRA]] and [[concepts/qlora|QLoRA]] within the broader PEFT landscape
- Relevant to all other sources in this wiki as the foundational survey