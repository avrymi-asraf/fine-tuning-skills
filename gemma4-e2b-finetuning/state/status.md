# Implementation Status

## PLAN.md Checklist

### Core Files
- [x] PLAN.md — exists
- [x] Dockerfile — multi-stage uv build, Vertex AI entrypoint, Unsloth support, GCS integration
- [x] .dockerignore — standard ML excludes
- [x] requirements.txt — updated versions for Gemma 4, removed unnecessary llama-cpp-python
- [x] configs/unsloth_lora.yaml — has load_in_4bit, complete hyperparams
- [x] configs/hf_qlora.yaml — complete with QLoRA config
- [x] configs/vertex_job.yaml — placeholder docs + Secret Manager guidance
- [x] data/prepare_dataset.py — max_seq_length filtering, Gemma 4 template validation, alpaca adapter
- [x] train_unsloth.py — AIP env vars, GCS I/O, checkpoint resumption (including AIP_CHECKPOINT_DIR)
- [x] train_hf_peft.py — AIP env vars, GCS I/O, checkpoint resumption (including AIP_CHECKPOINT_DIR)
- [x] inference.py — supports merged models and LoRA adapters, interactive chat
- [x] export.py — adapter save, 16-bit merge, GGUF export via Unsloth

### All Done
All files from the recommended structure in PLAN.md §9 are implemented and complete.