# Manager Memory — Qwen 3.5 2B Fine-Tuning Project

## Goal
Create a local fine-tuning project for **Qwen/Qwen3.5-2B** by copying and adapting the existing `gemma4-e2b-finetuning/` project. The user explicitly wants to focus on **local fine-tuning**, not cloud/Vertex AI.

## Source Project
- `gemma4-e2b-finetuning/` — originally built for Google Gemma 4 E2B (Effective 2B)
- Uses HF TRL + PEFT + QLoRA
- Has cloud-specific files (Vertex AI, GCS, Docker, etc.)

## Target Project
- `qwen3.5-2b-finetuning/` — adapted for Qwen/Qwen3.5-2B
- Focus: **local fine-tuning only**
- Keep Docker as optional local containerization
- Remove or minimize cloud-specific content

## Plan
1. Copy `gemma4-e2b-finetuning/` → `qwen3.5-2b-finetuning/`
2. Update all model references from `google/gemma-4-E2B-it` → `Qwen/Qwen3.5-2B`
3. Update LoRA target modules for Qwen architecture (qwen uses `c_attn`, `c_proj`, `w1`, `w2` or similar — need to verify)
4. Update chat template handling (Qwen uses its own chat template)
5. Update project metadata (pyproject.toml, README/PLAN)
6. Remove/minimize cloud-specific files (vertex_job.yaml, tasks.py cloud refs)
7. Update Dockerfile labels and comments
8. Verify all scripts work for local execution

## Qwen 3.5 2B Architecture Notes
- Model: `Qwen/Qwen3.5-2B` (base) or `Qwen/Qwen3.5-2B-Instruct` (chat)
- Architecture: Modified transformer with SwiGLU, RoPE, RMSNorm
- Likely LoRA targets: `c_attn`, `c_proj`, `w1`, `w2` (need to verify exact names)
- Chat template: Qwen uses `<|im_start|>user\n...<|im_end|>\n<|im_start|>assistant\n...`

## Status
- [ ] Directory copied
- [ ] Model references updated
- [ ] Configs updated
- [ ] Scripts updated
- [ ] Cloud files cleaned
- [ ] PLAN.md rewritten for local focus

## Next Step
Copy the directory and begin systematic updates.
