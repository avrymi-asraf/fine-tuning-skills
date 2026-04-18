# Implementation Status

## PLAN.md Checklist

### Core Files
- [x] PLAN.md — exists (local-first Qwen 3.5 2B)
- [x] Dockerfile — multi-stage uv build, optional Vertex AI entrypoint, GCS integration
- [x] .dockerignore — standard ML excludes
- [x] requirements.txt — updated versions for Qwen 3.5 2B
- [x] configs/hf_qlora.yaml — complete with QLoRA config for Qwen 3.5 2B
- [x] configs/vertex_job.yaml — placeholder docs + Secret Manager guidance (optional cloud)
- [x] data/prepare_dataset.py — max_seq_length filtering, Qwen chat template validation, alpaca adapter
- [x] train_hf_peft.py — AIP env vars, GCS I/O, checkpoint resumption (including AIP_CHECKPOINT_DIR)
- [x] inference.py — supports merged models and LoRA adapters, interactive chat
- [x] export.py — adapter save, 16-bit merge, GGUF export via Unsloth

### All Done
All files from the recommended structure in PLAN.md §8 are implemented and complete.