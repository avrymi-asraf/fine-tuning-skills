# Gemma 4

> Google's most capable open multimodal model family, released April 2026. Built from Gemini 3 research and technology. Licensed under Apache 2.0.

---

## Overview

Gemma 4 is a family of open-weights language models developed by Google DeepMind. It represents a significant leap over Gemma 3, particularly in reasoning, coding, agentic capabilities, and multimodal understanding. The family is designed to deliver frontier-level intelligence across a wide range of hardware—from edge devices and mobile phones to high-end workstations and data-center GPUs.

---

## Model Variants

| Variant | Architecture | Effective/Active Params | Total Params | Layers | Context | Modalities |
|---------|-------------|------------------------|--------------|--------|---------|------------|
| **E2B** | Dense | 2.3B | 5.1B* | 35 | 128K | Text, Image, Audio |
| **E4B** | Dense | 4.5B | 8B* | 42 | 128K | Text, Image, Audio |
| **26B A4B** | MoE | 3.8B active | 25.2B | 30 | 256K | Text, Image |
| **31B** | Dense | 30.7B | 30.7B | 60 | 256K | Text, Image |

\* *Total includes Per-Layer Embedding (PLE) tables. Effective params reflect the compute footprint during inference.*

### Naming Conventions
- **E** = *Effective* parameters (E2B, E4B). The smaller models use PLE to keep inference compute low while maintaining vocabulary coverage.
- **A** = *Active* parameters (26B A4B). In the MoE model, only 3.8B parameters are activated per token, yielding latency comparable to a 4B dense model.

---

## Architecture Highlights

### Hybrid Attention
Gemma 4 interleaves **local sliding window attention** with **full global attention**, ensuring the final layer is always global. This balances:
- Fast, memory-efficient local processing for most layers.
- Deep, long-range awareness where it matters.

### Proportional RoPE (p-RoPE)
Applied in global layers to reduce memory pressure for long-context sequences.

### Per-Layer Embeddings (PLE)
Instead of a single large shared embedding table, E2B and E4B give each decoder layer its own small embedding lookup. The tables are large in aggregate but only used for quick lookups, so the *effective* parameter count (and thus compute) remains small.

### MoE Routing
The 26B A4B uses **8 active experts out of 128 total**, plus 1 shared expert. This sparse design delivers high capacity without proportional inference cost.

---

## Performance

### Arena AI Rankings (as of Apr 2026)
- **31B**: #3 open model globally
- **26B A4B**: #6 open model globally
- Both outcompete models ~20× their size.

### Selected Benchmarks

| Benchmark | E2B | E4B | 26B A4B | 31B |
|-----------|-----|-----|---------|-----|
| MMLU Pro | 60.0% | 69.4% | 82.6% | 85.2% |
| AIME 2026 (no tools) | 37.5% | 42.5% | 88.3% | 89.2% |
| LiveCodeBench v6 | 44.0% | 52.0% | 77.1% | 80.0% |
| GPQA Diamond | 43.4% | 58.6% | 82.3% | 84.3% |
| MMMU Pro (Vision) | 44.2% | 52.6% | 73.8% | 76.9% |
| MATH-Vision | 52.4% | 59.5% | 82.4% | 85.6% |
| MRCR v2 128K | 19.1% | 25.4% | 44.1% | 66.4% |

### Accuracy-Efficiency Tradeoffs
Research (arXiv:2604.07035) benchmarking Gemma 4 against Phi-4 and Qwen3 shows:
- **Gemma-4-E4B + few-shot CoT** achieves the best overall accuracy-efficiency point (0.675 weighted accuracy at ~14.9 GB VRAM).
- **Gemma-4-26B-A4B** is close in accuracy (0.663) but much more memory-intensive (~48.1 GB VRAM).
- Gemma models dominate **ARC-Challenge** and **Math** tasks.
- Sparse activation alone does not guarantee the best practical operating point; optimal deployment depends on architecture, prompting, and task mix.

---

## Capabilities

### Reasoning (Thinking Mode)
All Gemma 4 models support configurable reasoning via the `<|think|>` token:
- Enabled: model emits internal reasoning in `<|channel>thought
...
<channel|>` tags before the final answer.
- Disabled (default for E2B/E4B): no empty thought blocks generated, unlike larger variants.

### Agentic Workflows
- Native **function calling**
- Structured **JSON output**
- Native **`system` role** support

### Multimodal
- **Images**: Variable aspect ratio and resolution (token budgets: 70, 140, 280, 560, 1120). Supports OCR, document parsing, chart understanding, UI/screen comprehension.
- **Video**: Processed as frame sequences (max 60s at 1 fps).
- **Audio** (E2B/E4B only): Automatic speech recognition (ASR) and speech-to-translated-text. Max audio length: 30 seconds.

### Coding
Strong offline code generation, completion, and correction. Codeforces ELO reaches 2150 for 31B.

### Languages
Out-of-the-box support for 35+ languages; pre-trained on 140+ languages.

---

## Deployment Targets

| Variant | Target Hardware |
|---------|-----------------|
| E2B | High-end phones, Raspberry Pi, NVIDIA Jetson Orin Nano |
| E4B | Laptops, tablets, edge accelerators |
| 26B A4B | Consumer GPUs (quantized), workstation GPUs |
| 31B | Single 80GB H100 (bf16), developer workstations |

### Ecosystem Support (Day One)
Hugging Face Transformers, TRL, Transformers.js, Candle, vLLM, llama.cpp, MLX, Ollama, Unsloth, SGLang, LiteRT-LM, NVIDIA NIM, NeMo, LM Studio, Cactus, Baseten, Docker, MaxText, Tunix, Keras.

### Google Cloud Integration
- Vertex AI Model Garden
- Cloud Run GPU serving
- GKE (vLLM tutorials available)
- TPU-accelerated serving
- Sovereign Cloud

---

## Fine-Tuning

Gemma 4 is explicitly designed for efficient fine-tuning:
- **E2B/E4B**: Ideal for on-device or consumer-GPU fine-tuning (e.g., with LoRA/QLoRA).
- **26B/31B**: Strong foundation for task-specific fine-tuning on workstations or cloud GPUs.
- Apache 2.0 license enables unrestricted commercial adaptation.

For fine-tuning guidance, see:
- [[concepts/parameter-efficient-fine-tuning|Parameter-Efficient Fine-Tuning]]
- [[concepts/lora|LoRA]]
- [[concepts/qlora|QLoRA]]

---

## Comparison with Gemma 3

| Aspect | Gemma 3 | Gemma 4 |
|--------|---------|---------|
| License | Custom (some restrictions) | Apache 2.0 |
| Max context | 128K | 128K (E2B/E4B), 256K (26B/31B) |
| Native audio | No | Yes (E2B/E4B) |
| Native system role | No | Yes |
| Function calling | Limited | Native |
| Reasoning mode | No | Configurable thinking |
| Arena ranking | 27B at ~#15 | 31B at #3, 26B at #6 |

---

## Competitive Landscape

Gemma 4 operates in a crowded field of open models. Key competitors by tier:

### Edge / Small (<5B)
- **Microsoft Phi-4-mini** (3.8B, MIT license, 128K context, text + multimodal variant) — strong math/reasoning but no native audio like Gemma 4 E2B/E4B.
- **Qwen3** (0.6B–4B, Apache 2.0, 32K context) — hybrid thinking modes, 119 languages, but no native multimodal support in base text models.

### Mid-Size (~24B–32B)
- **Qwen3-30B-A3B / 32B** (MoE + dense, 128K context) — Qwen3-30B-A3B has 3B active params, comparable latency to small dense models.
- **Mistral Small 3** (24B dense, Apache 2.0, 32K context) — strong agentic/function calling, fits on RTX 4090, but no multimodal support.

### Large (>100B)
- **Llama 4 Scout / Maverick** (109B / 400B total MoE, 10M / 1M context) — native multimodal, extremely long context, but custom license and no audio.
- **DeepSeek-V3** (685B MoE, 128K context) — cost-efficient training, strong coding, but no native multimodal support.

### Gemma 4's Key Differentiators
1. **Unified multimodal family**: All sizes handle text + image; small sizes add audio.
2. **Extreme context at small sizes**: 128K on E2B/E4B edge models is rare.
3. **Apache 2.0 across all sizes**: No custom commercial restrictions.
4. **Intelligence-per-parameter**: 31B ranks #3 open model globally, outperforming models 20× larger.
5. **On-device optimization**: Co-designed with mobile hardware partners.

For a detailed competitor comparison, see [[sources/2026-gemma-4-competitors|Gemma 4 Competitors]].

---

## See Also

- [[sources/2026-gemma-4-family|Gemma 4 Family (Source Page)]] — Detailed source summary with benchmark tables and citations.
- [[sources/2026-gemma-4-competitors|Gemma 4 Competitors]] — Full competitive landscape analysis.
- [[concepts/parameter-efficient-fine-tuning|PEFT]] — Fine-tuning methods for adapting Gemma 4.
- [[concepts/qlora|QLoRA]] — Quantized fine-tuning for edge deployment.

---

## External Links

- Hugging Face Collection: https://huggingface.co/collections/google/gemma-4
- Google AI Studio (31B/26B): https://aistudio.google.com/prompts/new_chat?model=gemma-4-31b-it
- Google Blog Announcement: https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/
- arXiv Benchmark Paper: https://arxiv.org/abs/2604.07035
