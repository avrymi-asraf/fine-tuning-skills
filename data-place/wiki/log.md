# Wiki Log

> Append-only chronological record of wiki activity.

## [2026-04-11] ingest | Few-Shot Fine-Tuning Sources

Added 2 PDF sources on few-shot fine-tuning techniques:

**Sources Ingested:**
1. `Few-Shot Fine-Tuning Techniques Overview` (356 KB, Google Docs)
2. `Few-Shot Parameter-Efficient Fine-Tuning is Better` (531 KB, Academic Paper)

**Wiki Pages Created:**
- `wiki/sources/few-shot-fine-tuning-techniques-overview.md`
- `wiki/sources/few-shot-parameter-efficient-fine-tuning-is-better.md`
- `wiki/concepts/parameter-efficient-fine-tuning.md`
- `wiki/concepts/lora.md`
- `wiki/concepts/qlora.md`

**Database Created:**
- `articles.db` — SQLite database with full-text search indexing both sources

**Cross-References:**
- Source pages link to relevant concept pages
- Concept pages link to source pages
- All pages reference index

## [2026-04-13] ingest | Web Research: Fine-Tuning with Few Examples

Searched the web for recent articles on fine-tuning LLMs with limited data. Found and ingested 8 high-quality sources covering surveys, extreme parameter efficiency, synthetic data, data selection, RL-based tuning, and forgetting mitigation.

**Sources Ingested:**
1. `2024-finetuning-llms-limited-data-survey.md` — TACL survey on limited-data fine-tuning (arXiv:2411.09539)
2. `2025-few-shot-fine-tuning-10-examples.md` — distil labs practical guide to 10-example fine-tuning
3. `2026-tinylora-extreme-parameter-efficiency.md` — TinyLoRA: 13 params → 91.8% GSM8K (arXiv:2602.04118)
4. `2025-data-whisperer-efficient-data-selection.md` — Data Whisperer: training-free data selection (ACL 2025)
5. `2025-optimization-inspired-few-shot-adaptation.md` — OFA: LayerNorm preconditioners for few-shot adaptation (arXiv:2505.19107)
6. `2025-minifinetuning-corrective-self-distillation.md` — MiniFineTuning: corrective self-distillation (NVIDIA, arXiv:2506.15702)
7. `2025-finetuned-in-context-learners.md` — Fine-tuned ICL unifying prompting and fine-tuning (arXiv:2512.19879)
8. `2026-efficient-strategy-finetuning-frontiers.md` — DSS + LoRA/QLoRA end-to-end strategy (Frontiers in AI 2026)

**Wiki Pages Created:**
- `wiki/sources/2024-finetuning-llms-limited-data-survey.md`
- `wiki/sources/2025-few-shot-fine-tuning-10-examples.md`
- `wiki/sources/2026-tinylora-extreme-parameter-efficiency.md`
- `wiki/sources/2025-data-whisperer-efficient-data-selection.md`
- `wiki/sources/2025-optimization-inspired-few-shot-adaptation.md`
- `wiki/sources/2025-minifinetuning-corrective-self-distillation.md`
- `wiki/sources/2025-finetuned-in-context-learners.md`
- `wiki/sources/2026-efficient-strategy-finetuning-frontiers.md`
- `wiki/concepts/synthetic-data-generation.md`
- `wiki/concepts/data-selection-for-finetuning.md`
- `wiki/concepts/rl-based-finetuning.md`
- `wiki/concepts/catastrophic-forgetting-mitigation.md`

**Wiki Pages Updated:**
- `wiki/concepts/parameter-efficient-fine-tuning.md` — Added TinyLoRA, OFA, survey references
- `wiki/concepts/lora.md` — Added TinyLoRA variants and 4:1 alpha-to-rank guidance
- `wiki/concepts/qlora.md` — Added DSS+QLoRA and MFT composability notes
- `wiki/index.md` — Updated catalog with all new pages

**Key Themes Across Sources:**
- PEFT and extreme parameter efficiency (TinyLoRA pushes to 13 parameters)
- Synthetic data amplification (distil labs, DSS)
- Training-free data selection (Data Whisperer)
- RL superiority over SFT in low-parameter regimes (TinyLoRA)
- Forgetting mitigation without replay data (MiniFineTuning)
- Unification of ICL and fine-tuning (Fine-Tuned ICL)
