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

## [2026-04-16] ingest | Web Research: Gemma 4 Model Family

Searched the web for information on Gemma 4 (triggered by query "gemma4 2e4"). Synthesized findings from Google Blog announcement, Hugging Face model cards, and arXiv benchmark paper.

**Sources Ingested:**
1. Google Blog — "Gemma 4: Byte for byte, the most capable open models" (Apr 2, 2026)
2. Hugging Face — `google/gemma-4-E2B-it` and `google/gemma-4-E4B-it` model cards
3. Manik & Wang — arXiv:2604.07035 on accuracy-efficiency tradeoffs in Gemma 4, Phi-4, and Qwen3

**Wiki Pages Created:**
- `wiki/sources/2026-gemma-4-family.md` — Source summary with architecture, benchmarks, and deployment details
- `wiki/entities/gemma-4.md` — Entity page covering the full model family, capabilities, and fine-tuning notes

**Wiki Pages Updated:**
- `wiki/index.md` — Added Gemma 4 source and entity entries

**Key Findings:**
- Gemma 4 comes in four sizes: E2B (2.3B effective), E4B (4.5B effective), 26B A4B MoE (3.8B active), and 31B Dense
- E2B/E4B support native audio; all models support images/video
- 31B ranks #3 and 26B A4B ranks #6 on Arena AI open-source leaderboard
- Apache 2.0 license removes commercial restrictions
- arXiv:2604.07035 shows Gemma-4-E4B + few-shot CoT is the best accuracy-efficiency point (0.675 accuracy at ~14.9 GB VRAM)
- Strong ecosystem support: Transformers, vLLM, llama.cpp, MLX, Ollama, Unsloth, Vertex AI, etc.

## [2026-04-16] ingest | Web Research: Gemma 4 Competitors

Searched the web for models similar to Gemma 4 across edge, mid-size, and large tiers.

**Sources Ingested:**
1. Hugging Face — `microsoft/Phi-4-mini-instruct` model card
2. Qwen Team — Qwen3 blog and Hugging Face collection
3. Meta — `meta-llama/Llama-4-Scout-17B-16E-Instruct` model card
4. Mistral AI — `mistralai/Mistral-Small-24B-Instruct-2501` model card
5. DeepSeek-AI — DeepSeek-V3 collection

**Wiki Pages Created:**
- `wiki/sources/2026-gemma-4-competitors.md` — Competitive landscape analysis by model tier

**Wiki Pages Updated:**
- `wiki/entities/gemma-4.md` — Added Competitive Landscape section with cross-reference to competitors page
- `wiki/index.md` — Added Gemma 4 Competitors source entry

**Key Findings:**
- **Edge (<5B)**: Phi-4-mini (3.8B, MIT, 128K) and Qwen3 (0.6B–4B, Apache 2.0, 32K) are the closest rivals. Gemma 4 E2B/E4B differentiate with native audio + 128K context.
- **Mid-size (~24B–32B)**: Qwen3-30B-A3B/32B and Mistral Small 3 (24B) compete here. Gemma 4 26B/31B offer longer context (256K) and native multimodal support.
- **Large (>100B)**: Llama 4 Scout/Maverick and DeepSeek-V3 dominate. Llama 4 Scout's 10M context is unmatched, but Gemma 4 31B achieves superior intelligence-per-parameter (#3 on Arena AI).
- Gemma 4's Apache 2.0 license is simpler than Llama 4's custom license and DeepSeek's model license.
