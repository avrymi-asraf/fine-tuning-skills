# Gemma 4: Google's Open Multimodal Model Family

> Source: Web research synthesis from Google Blog (Apr 2026), Hugging Face model cards, and arXiv:2604.07035.  
> Query trigger: "gemma4 2e4"

---

## Summary

**Gemma 4** is Google's most capable open model family to date, released in April 2026 under the Apache 2.0 license. It is built from the same research and technology as Gemini 3, designed for advanced reasoning, agentic workflows, coding, and multimodal understanding. The family includes four sizes: **E2B** (Effective 2B), **E4B** (Effective 4B), **26B A4B MoE**, and **31B Dense**.

---

## Model Variants

| Model | Architecture | Effective/Active Params | Total Params | Context | Modalities |
|-------|-------------|------------------------|--------------|---------|------------|
| **Gemma 4 E2B** | Dense | 2.3B effective | 5.1B (with PLE embeddings) | 128K | Text, Image, **Audio** |
| **Gemma 4 E4B** | Dense | 4.5B effective | 8B (with PLE embeddings) | 128K | Text, Image, **Audio** |
| **Gemma 4 26B A4B** | MoE | 3.8B active | 25.2B total | 256K | Text, Image |
| **Gemma 4 31B** | Dense | 30.7B | 30.7B | 256K | Text, Image |

### Key Architectural Notes
- **Per-Layer Embeddings (PLE)**: Used in E2B/E4B to maximize on-device efficiency. Each decoder layer has its own small embedding table. These tables are large but used only for lookups, making the *effective* parameter count much smaller than total.
- **Hybrid Attention**: Interleaves local sliding window attention with full global attention; the final layer is always global.
- **Proportional RoPE (p-RoPE)**: Applied in global layers to optimize memory for long contexts.
- **MoE Design**: 26B A4B uses 8 active experts out of 128 total (+ 1 shared), running almost as fast as a 4B dense model during inference.

---

## Benchmarks (Instruction-Tuned)

| Benchmark | 31B | 26B A4B | E4B | E2B | Gemma 3 27B |
|-----------|-----|---------|-----|-----|-------------|
| MMLU Pro | 85.2% | 82.6% | 69.4% | 60.0% | 67.6% |
| AIME 2026 (no tools) | 89.2% | 88.3% | 42.5% | 37.5% | 20.8% |
| LiveCodeBench v6 | 80.0% | 77.1% | 52.0% | 44.0% | 29.1% |
| Codeforces ELO | 2150 | 1718 | 940 | 633 | 110 |
| GPQA Diamond | 84.3% | 82.3% | 58.6% | 43.4% | 42.4% |
| MMMU Pro (Vision) | 76.9% | 73.8% | 52.6% | 44.2% | 49.7% |
| MATH-Vision | 85.6% | 82.4% | 59.5% | 52.4% | 46.0% |
| MRCR v2 8 needle 128k | 66.4% | 44.1% | 25.4% | 19.1% | 13.5% |

> **Notable result**: Gemma 4 31B ranks #3 on the Arena AI open-source text leaderboard; 26B A4B ranks #6, outcompeting models 20× their size.

---

## Core Capabilities

1. **Reasoning / Thinking Mode**: Configurable step-by-step reasoning via `<|think|>` token. Can be enabled/disabled at inference time.
2. **Agentic Workflows**: Native function calling, structured JSON output, and native system prompt support.
3. **Multimodal**: 
   - All models: text, images (variable aspect ratio/resolution), video (as frame sequences).
   - E2B/E4B only: native audio input (ASR, speech-to-translated-text). Max audio length: 30s. Max video: 60s.
4. **Long Context**: 128K for edge models (E2B/E4B), 256K for larger models.
5. **Coding**: Strong offline code generation and completion.
6. **Multilingual**: 35+ languages out-of-the-box; pre-trained on 140+ languages.

---

## Deployment & Ecosystem

- **Edge/On-Device**: E2B and E4B are optimized for phones (Pixel, Qualcomm, MediaTek), Raspberry Pi, and NVIDIA Jetson Orin Nano.
- **Workstation**: 26B and 31B fit on a single 80GB H100 in bfloat16; quantized versions run on consumer GPUs.
- **Day-One Tooling**: Hugging Face Transformers, TRL, vLLM, llama.cpp, MLX, Ollama, Unsloth, SGLang, LiteRT-LM, NVIDIA NIM/NeMo, Keras, MaxText.
- **Google Cloud**: Vertex AI, Cloud Run, GKE, TPU serving.

---

## Accuracy-Efficiency Tradeoffs (arXiv:2604.07035)

A controlled benchmark of 8,400 evaluations across Gemma-4-E2B, Gemma-4-E4B, Gemma-4-26B-A4B, Phi-4-mini-reasoning, Phi-4-reasoning, Qwen3-8B, and Qwen3-30B-A3B found:

- **Gemma-4-E4B with few-shot chain-of-thought** achieved the best overall weighted accuracy (0.675) with mean VRAM of 14.9 GB.
- **Gemma-4-26B-A4B** was close in accuracy (0.663) but required 48.1 GB VRAM.
- Gemma models dominated **ARC** and **Math** tasks.
- Sparse activation (MoE) alone does not guarantee the best practical operating point; the optimal choice depends on architecture, prompting protocol, and task composition.

---

## Fine-Tuning Notes

- All Gemma 4 models support fine-tuning via standard frameworks (Hugging Face TRL, Unsloth, etc.).
- The E2B/E4B sizes are specifically designed for efficient local fine-tuning on limited hardware.
- Apache 2.0 license removes commercial restrictions present in earlier Gemma releases.

---

## Related Pages

- [[entities/gemma-4|Gemma 4 (Entity)]] — Model family details, architecture, and deployment guidance.
- [[concepts/parameter-efficient-fine-tuning|Parameter-Efficient Fine-Tuning]] — Methods applicable to Gemma 4 fine-tuning.
- [[concepts/qlora|QLoRA]] — Quantized fine-tuning suitable for edge and consumer GPU deployment.

---

## References

1. Google Blog — "Gemma 4: Byte for byte, the most capable open models" (Apr 2, 2026). https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/
2. Hugging Face — `google/gemma-4-E2B-it` and `google/gemma-4-E4B-it` model cards. https://huggingface.co/collections/google/gemma-4
3. Manik & Wang — "Gemma 4, Phi-4, and Qwen3: Accuracy-Efficiency Tradeoffs in Dense and MoE Reasoning Language Models." arXiv:2604.07035 (Apr 2026).
