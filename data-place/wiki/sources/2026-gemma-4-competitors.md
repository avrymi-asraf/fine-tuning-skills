# Models Similar to Gemma 4: Competitive Landscape

> Source: Web research synthesis from Hugging Face model cards, official blogs, and technical reports (Apr 2026).  
> Focus: Open models comparable to Gemma 4 across edge (2B–4B), mid-size (~30B), and large (~100B+) segments.

---

## Summary

Gemma 4 competes in a crowded landscape of open-weights language models. The closest competitors vary by size tier:

- **Edge / Small (<5B)**: Phi-4-mini, Qwen3-4B/1.7B/0.6B
- **Mid-size / Workstation (~30B)**: Qwen3-30B-A3B, Qwen3-32B, Mistral Small 3 (24B), Llama 4 Scout (109B total / 17B active)
- **Large / Data-center (>100B)**: Llama 4 Maverick (400B total / 17B active), Qwen3-235B-A22B, DeepSeek-V3 (685B total)

This page catalogs the key architectural differences, licensing, and benchmark positioning of these alternatives.

---

## Edge / Small Models (<5B Parameters)

These are designed for on-device, low-latency, and memory-constrained deployment.

### Microsoft Phi-4-mini-instruct

| Property | Value |
|----------|-------|
| **Parameters** | 3.8B dense |
| **Context** | 128K |
| **Architecture** | Dense decoder-only, GQA, 200K vocab, shared input/output embeddings |
| **Modalities** | Text (multimodal variant: Phi-4-multimodal-instruct) |
| **License** | MIT |
| **Release** | Feb 2025 |

**Key traits:**
- Trained on 5T tokens with heavy synthetic data for math/reasoning.
- Strong at GSM8K (88.6%) and MATH (64.0%) for its size.
- Beats Llama-3.2-3B, Mistral-3B, and Qwen2.5-3B on aggregated benchmarks; approaches Qwen2.5-7B and Gemma2-9B levels.
- Supports function calling and chat formats.
- No native audio (unlike Gemma 4 E2B/E4B).

**Comparison to Gemma 4 E2B/E4B:**
- Phi-4-mini is smaller than E4B (3.8B vs 4.5B effective) but lacks native audio.
- Gemma 4 E2B/E4B have larger context (128K vs 128K — tied), but Gemma 4 adds multimodal audio + vision natively.
- Phi-4-mini uses MIT license (very permissive); Gemma 4 uses Apache 2.0 (also permissive).

---

### Qwen3 Family (0.6B – 4B)

| Model | Params | Context | Architecture |
|-------|--------|---------|--------------|
| Qwen3-0.6B | 0.6B | 32K | Dense, tied embeddings |
| Qwen3-1.7B | 1.7B | 32K | Dense, tied embeddings |
| Qwen3-4B | 4B | 32K | Dense, tied embeddings |

**Key traits:**
- Pre-trained on ~36T tokens (double Qwen2.5's 18T).
- Supports **hybrid thinking modes**: switch between step-by-step reasoning and fast responses via `enable_thinking` flag.
- 119 languages supported.
- Apache 2.0 license.
- Strong ecosystem: SGLang, vLLM, Ollama, LMStudio, MLX, llama.cpp, KTransformers.

**Comparison to Gemma 4 E2B/E4B:**
- Qwen3-4B is closest to Gemma 4 E4B in raw parameter count.
- Qwen3 small models have **much shorter context** (32K vs 128K).
- No native multimodal support in the base text models (Qwen3-VL handles vision separately).
- Qwen3's hybrid thinking mode is a direct competitor to Gemma 4's configurable thinking.

---

## Mid-Size Models (~24B–32B)

These target consumer GPUs, workstations, and high-throughput serving.

### Qwen3-30B-A3B / Qwen3-32B

| Model | Architecture | Active/Total | Context |
|-------|-------------|--------------|---------|
| Qwen3-30B-A3B | MoE | 3B active / 30B total | 128K |
| Qwen3-32B | Dense | 32B | 128K |

**Key traits:**
- Qwen3-30B-A3B is an MoE model with only 3B active parameters per token — comparable latency to a small dense model.
- Both support hybrid thinking modes.
- Apache 2.0 license.

**Comparison to Gemma 4 26B A4B / 31B:**
- Gemma 4 26B A4B has 3.8B active / 25.2B total with 256K context; Qwen3-30B-A3B has 3B active / 30B total with 128K context.
- Gemma 4 31B dense offers 256K context vs Qwen3-32B's 128K.
- arXiv:2604.07035 shows Gemma-4-E4B actually outperforms Qwen3-8B on some reasoning tasks, while Gemma-4-26B-A4B is competitive with Qwen3-30B-A3B.

---

### Mistral Small 3 (24B Instruct)

| Property | Value |
|----------|-------|
| **Parameters** | 24B dense |
| **Context** | 32K |
| **License** | Apache 2.0 |
| **Release** | Jan 2025 |

**Key traits:**
- Marketed as "knowledge-dense" — fits on a single RTX 4090 or 32GB MacBook when quantized.
- Strong function calling and agentic capabilities.
- MMLU Pro: 0.663; HumanEval: 0.848; competitive with Gemma-2-27B, Qwen2.5-32B, Llama-3.3-70B.
- Uses Tekken tokenizer (131K vocab).

**Comparison to Gemma 4 26B/31B:**
- Mistral Small 3 is dense 24B with only 32K context — much shorter than Gemma 4's 256K.
- No native multimodal support (text-only).
- Gemma 4 31B and 26B A4B are newer (Apr 2026) and should outperform on most benchmarks.
- Mistral's ecosystem integration is excellent (vLLM, Ollama, etc.).

---

## Large Models (>100B Total Parameters)

These are data-center grade, often MoE, competing with frontier closed models.

### Llama 4 Scout / Maverick

| Model | Architecture | Active / Total | Context | Modalities |
|-------|-------------|----------------|---------|------------|
| Llama 4 Scout | MoE | 17B active / 109B total | 10M | Text, Image |
| Llama 4 Maverick | MoE | 17B active / 400B total | 1M | Text, Image |

**Key traits:**
- Native multimodal with **early fusion**.
- Extremely long context: Scout supports **10M tokens** (the longest in the open model space).
- Trained on ~40T tokens (Scout) and ~22T tokens (Maverick).
- Custom **Llama 4 Community License** (commercial use allowed, but 700M+ MAU requires a separate Meta license).

**Comparison to Gemma 4:**
- Llama 4 Scout/Maverick are in a different size class than Gemma 4's largest 31B model.
- Llama 4's 10M context (Scout) dwarfs Gemma 4's 256K.
- Gemma 4's E2B/E4B have native audio; Llama 4 does not.
- Gemma 4 uses Apache 2.0, which is simpler and more permissive than Llama 4's custom license.
- Gemma 4 31B ranks #3 on Arena AI open-source leaderboard, suggesting it punches above its weight relative to Llama 4 Maverick.

---

### DeepSeek-V3

| Property | Value |
|----------|-------|
| **Architecture** | MoE |
| **Total Parameters** | 685B |
| **Active Parameters** | ~37B per token |
| **Context** | 128K |
| **License** | DeepSeek Model License (permissive, with some restrictions) |
| **Release** | Dec 2024 |

**Key traits:**
- Extremely cost-efficient training (~$5.6M estimated for final run).
- Multi-head latent attention (MLA) for memory efficiency.
- Strong coding and reasoning performance; competitive with GPT-4o and Claude 3.5 Sonnet on many tasks.
- No native multimodal support in V3 (DeepSeek-VL2 and Janus handle vision).

**Comparison to Gemma 4:**
- DeepSeek-V3 is a pure text-generation data-center model, not a direct competitor to Gemma 4's edge-focused E2B/E4B variants.
- Gemma 4's MoE (26B A4B) is far smaller and targets different deployment scenarios.
- DeepSeek-V3 is not natively multimodal, whereas Gemma 4 integrates vision (and audio on small models).

---

## Competitive Positioning Matrix

| Model Family | Edge | Mid | Large | Multimodal | Audio | License |
|--------------|------|-----|-------|------------|-------|---------|
| **Gemma 4** | E2B, E4B | 26B A4B, 31B | — | ✅ (all) | ✅ (E2B/E4B) | Apache 2.0 |
| **Phi-4** | mini (3.8B) | — | reasoning (14B?) | ✅ (multimodal variant) | ✅ (multimodal) | MIT |
| **Qwen3** | 0.6B–4B | 30B-A3B, 32B | 235B-A22B | ❌ (VL separate) | ❌ | Apache 2.0 |
| **Llama 4** | — | — | Scout, Maverick | ✅ | ❌ | Llama 4 Community |
| **Mistral Small 3** | — | 24B | — | ❌ | ❌ | Apache 2.0 |
| **DeepSeek-V3** | — | — | 685B | ❌ | ❌ | DeepSeek License |

---

## Key Differentiators of Gemma 4

1. **Unified multimodal family**: All sizes handle text + image; small sizes add audio. Competitors often split modalities across separate model families (Qwen3 + Qwen3-VL, DeepSeek-V3 + DeepSeek-VL2).
2. **Extreme context at small sizes**: 128K on E2B/E4B edge models is rare; Phi-4-mini matches it, but Qwen3 small models only reach 32K.
3. **Apache 2.0 across all sizes**: No custom commercial restrictions (unlike Llama 4's 700M MAU clause or DeepSeek's license).
4. **Intelligence-per-parameter**: 31B ranks #3 and 26B A4B ranks #6 on Arena AI open-source leaderboard, outperforming models 20× larger.
5. **On-device optimization**: E2B/E4B are explicitly co-designed with mobile hardware partners (Pixel, Qualcomm, MediaTek).

---

## Related Pages

- [[entities/gemma-4|Gemma 4]] — Full entity page for the Gemma 4 model family.
- [[sources/2026-gemma-4-family|Gemma 4 Family (Source Page)]] — Detailed source summary with benchmarks.

---

## References

1. Microsoft — `microsoft/Phi-4-mini-instruct` model card. https://huggingface.co/microsoft/Phi-4-mini-instruct
2. Qwen Team — "Qwen3: Think Deeper, Act Faster" (Apr 2025). https://qwenlm.github.io/blog/qwen3/
3. Meta — `meta-llama/Llama-4-Scout-17B-16E-Instruct` model card. https://huggingface.co/meta-llama/Llama-4-Scout-17B-16E-Instruct
4. Mistral AI — `mistralai/Mistral-Small-24B-Instruct-2501` model card. https://huggingface.co/mistralai/Mistral-Small-24B-Instruct-2501
5. DeepSeek-AI — DeepSeek-V3 Collection. https://huggingface.co/collections/deepseek-ai/deepseek-v3
6. Manik & Wang — arXiv:2604.07035 on accuracy-efficiency tradeoffs across Gemma 4, Phi-4, and Qwen3.
