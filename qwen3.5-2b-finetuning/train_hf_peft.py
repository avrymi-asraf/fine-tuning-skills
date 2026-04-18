#!/usr/bin/env python3
"""
Training script for Qwen 3.5 2B using standard HF TRL + PEFT + QLoRA.
Primary path: local training. Cloud (Vertex AI) is optional — GCS helpers
remain functional but default to local paths.
Supports: local training, Vertex AI custom jobs, GCS I/O, checkpoint resumption.
"""

import argparse
import os
import yaml
import torch
from datasets import load_from_disk
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    BitsAndBytesConfig,
    TrainingArguments,
)
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training, TaskType
from trl import SFTTrainer

# ---------------------------------------------------------------------------
# Workaround: if bitsandbytes is installed but cannot compile its Triton
# kernels (e.g. missing python3-dev headers), force PEFT to skip the bnb
# code-path so LoRA injection succeeds on plain bf16/fp16 weights.
# ---------------------------------------------------------------------------
try:
    import bitsandbytes as _bnb  # noqa: F401
except Exception:
    import peft.import_utils
    import peft.tuners.lora.model as _lora_model

    peft.import_utils.is_bnb_available = lambda: False
    _lora_model.is_bnb_available = lambda: False


# ---------------------------------------------------------------------------
# GCS helpers (same as train_unsloth.py)
# ---------------------------------------------------------------------------
def _gcs_client():
    try:
        from google.cloud import storage
        return storage.Client()
    except ImportError:
        return None


def gcs_download_dir(gcs_uri: str, local_dir: str) -> str:
    if not gcs_uri.startswith("gs://"):
        return gcs_uri
    client = _gcs_client()
    if client is None:
        print(f"[WARN] google-cloud-storage not installed; skipping GCS download of {gcs_uri}")
        return local_dir
    parts = gcs_uri.replace("gs://", "").split("/", 1)
    bucket_name = parts[0]
    prefix = parts[1] if len(parts) > 1 else ""
    bucket = client.bucket(bucket_name)
    blobs = list(bucket.list_blobs(prefix=prefix))
    os.makedirs(local_dir, exist_ok=True)
    for blob in blobs:
        if blob.name.endswith("/"):
            continue
        rel = blob.name[len(prefix):].lstrip("/")
        dest = os.path.join(local_dir, rel)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        blob.download_to_filename(dest)
    print(f"Downloaded {len(blobs)} objects from {gcs_uri} → {local_dir}")
    return local_dir


def gcs_upload_dir(local_dir: str, gcs_uri: str) -> None:
    if not gcs_uri.startswith("gs://"):
        return
    client = _gcs_client()
    if client is None:
        print(f"[WARN] google-cloud-storage not installed; skipping GCS upload to {gcs_uri}")
        return
    parts = gcs_uri.replace("gs://", "").split("/", 1)
    bucket_name = parts[0]
    prefix = parts[1] if len(parts) > 1 else ""
    bucket = client.bucket(bucket_name)
    count = 0
    for root, _, files in os.walk(local_dir):
        for fname in files:
            local_path = os.path.join(root, fname)
            rel = os.path.relpath(local_path, local_dir)
            blob_path = f"{prefix}/{rel}" if prefix else rel
            bucket.blob(blob_path).upload_from_filename(local_path)
            count += 1
    print(f"Uploaded {count} files from {local_dir} → {gcs_uri}")


def resolve_output_dir(cli_arg: str) -> str:
    return os.environ.get("AIP_MODEL_DIR", cli_arg)


def find_last_checkpoint(output_dir: str) -> str | None:
    from transformers.trainer_utils import get_last_checkpoint
    if os.path.isdir(output_dir):
        return get_last_checkpoint(output_dir)
    return None


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def load_config(config_path: str) -> dict:
    with open(config_path, "r") as f:
        return yaml.safe_load(f)


def main():
    parser = argparse.ArgumentParser(description="Qwen 3.5 2B HF PEFT QLoRA training")
    parser.add_argument("--config", type=str, default="configs/hf_qlora.yaml",
                        help="Path to YAML config")
    parser.add_argument("--dataset_path", type=str, default="data/formatted_dataset",
                        help="Local path or gs:// URI to dataset")
    parser.add_argument("--output_dir", type=str, default="outputs/hf-qwen3.5-2b",
                        help="Local output dir (overridden by AIP_MODEL_DIR on Vertex AI)")
    args = parser.parse_args()

    cfg = load_config(args.config)

    # --- Resolve paths ---
    output_dir = resolve_output_dir(args.output_dir)
    dataset_path = args.dataset_path

    if dataset_path.startswith("gs://"):
        dataset_path = gcs_download_dir(dataset_path, "/tmp/dataset")

    model_name = cfg["model_name"]

    # --- HF auth ---
    hf_token = os.environ.get("HF_TOKEN")
    if hf_token:
        from huggingface_hub import login
        login(token=hf_token)

    # --- Load tokenizer ---
    print(f"Loading tokenizer: {model_name}")
    tokenizer = AutoTokenizer.from_pretrained(model_name, token=hf_token)
    tokenizer.pad_token = tokenizer.eos_token
    tokenizer.padding_side = "right"

    # --- Load model ---
    if cfg.get("load_in_4bit", True):
        print("Loading model in 4-bit (QLoRA)...")
        bnb_config = BitsAndBytesConfig(
            load_in_4bit=cfg["load_in_4bit"],
            bnb_4bit_quant_type=cfg["bnb_4bit_quant_type"],
            bnb_4bit_compute_dtype=getattr(torch, cfg["bnb_4bit_compute_dtype"]),
            bnb_4bit_use_double_quant=cfg["bnb_4bit_use_double_quant"],
        )
        model = AutoModelForCausalLM.from_pretrained(
            model_name,
            quantization_config=bnb_config,
            device_map="auto",
            attn_implementation="eager",
            token=hf_token,
        )
        model = prepare_model_for_kbit_training(model)
    else:
        print("Loading model in bf16 (full precision + LoRA)...")
        model = AutoModelForCausalLM.from_pretrained(
            model_name,
            dtype=torch.bfloat16,
            device_map="auto",
            attn_implementation="eager",
            token=hf_token,
        )

    # --- LoRA ---
    print("Configuring LoRA...")
    peft_config = LoraConfig(
        r=cfg["lora_r"],
        lora_alpha=cfg["lora_alpha"],
        lora_dropout=cfg["lora_dropout"],
        target_modules=cfg["target_modules"],
        bias="none",
        task_type=TaskType.CAUSAL_LM,
    )
    model = get_peft_model(model, peft_config)
    model.print_trainable_parameters()

    # --- Load dataset ---
    print(f"Loading dataset from: {dataset_path}")
    dataset = load_from_disk(dataset_path)

    # --- Checkpoint resumption ---
    checkpoint_dir = os.environ.get("AIP_CHECKPOINT_DIR", output_dir)
    last_checkpoint = find_last_checkpoint(checkpoint_dir)
    if last_checkpoint:
        print(f"Resuming from checkpoint: {last_checkpoint}")
    elif os.path.isdir(checkpoint_dir) and checkpoint_dir != output_dir:
        last_checkpoint = find_last_checkpoint(output_dir)
        if last_checkpoint:
            print(f"Resuming from checkpoint: {last_checkpoint}")

    # --- Training args ---
    # TRL >= 0.15 uses SFTConfig instead of passing SFT-specific args directly
    # to SFTTrainer. We keep TrainingArguments for base HF args.
    try:
        from trl import SFTConfig
        training_args = SFTConfig(
            output_dir=output_dir,
            per_device_train_batch_size=cfg["per_device_train_batch_size"],
            gradient_accumulation_steps=cfg["gradient_accumulation_steps"],
            warmup_steps=cfg["warmup_steps"],
            max_steps=cfg["max_steps"],
            num_train_epochs=cfg.get("num_train_epochs"),
            learning_rate=cfg["learning_rate"],
            fp16=not torch.cuda.is_bf16_supported(),
            bf16=torch.cuda.is_bf16_supported(),
            logging_steps=cfg["logging_steps"],
            optim=cfg.get("optim", "adamw_torch"),
            weight_decay=cfg["weight_decay"],
            lr_scheduler_type=cfg["lr_scheduler_type"],
            seed=cfg["seed"],
            report_to=cfg.get("report_to", "none"),
            # group_by_length removed — not supported in this transformers version
            # Checkpointing
            save_strategy=cfg.get("save_strategy", "steps"),
            save_steps=cfg.get("save_steps", 100),
            save_total_limit=cfg.get("save_total_limit", 3),
            # SFT-specific args (only pass args SFTConfig actually accepts)
            dataset_text_field="text",
        )
    except ImportError:
        # Fallback for older TRL versions
        training_args = TrainingArguments(
            output_dir=output_dir,
            per_device_train_batch_size=cfg["per_device_train_batch_size"],
            gradient_accumulation_steps=cfg["gradient_accumulation_steps"],
            warmup_steps=cfg["warmup_steps"],
            max_steps=cfg["max_steps"],
            num_train_epochs=cfg.get("num_train_epochs"),
            learning_rate=cfg["learning_rate"],
            fp16=not torch.cuda.is_bf16_supported(),
            bf16=torch.cuda.is_bf16_supported(),
            logging_steps=cfg["logging_steps"],
            optim=cfg.get("optim", "adamw_torch"),
            weight_decay=cfg["weight_decay"],
            lr_scheduler_type=cfg["lr_scheduler_type"],
            seed=cfg["seed"],
            report_to=cfg.get("report_to", "none"),
            # group_by_length removed — not supported in this transformers version
            # Checkpointing
            save_strategy=cfg.get("save_strategy", "steps"),
            save_steps=cfg.get("save_steps", 100),
            save_total_limit=cfg.get("save_total_limit", 3),
        )

    # --- Train ---
    # Newer TRL uses `processing_class` instead of `tokenizer`
    sft_kwargs = dict(
        model=model,
        processing_class=tokenizer,
        train_dataset=dataset,
        args=training_args,
    )
    # Only pass dataset_text_field / max_seq_length for older TRL that expects them
    import inspect
    sft_sig = inspect.signature(SFTTrainer.__init__)
    if "dataset_text_field" in sft_sig.parameters:
        sft_kwargs["dataset_text_field"] = "text"
    if "max_seq_length" in sft_sig.parameters:
        sft_kwargs["max_seq_length"] = cfg["max_seq_length"]

    trainer = SFTTrainer(**sft_kwargs)

    print("Starting training...")
    trainer.train(resume_from_checkpoint=last_checkpoint)

    # --- Save adapter ---
    adapter_dir = os.path.join(output_dir, "lora_adapter")
    print(f"Saving adapter to {adapter_dir}")
    model.save_pretrained(adapter_dir)
    tokenizer.save_pretrained(adapter_dir)

    # --- Upload to GCS if running on Vertex AI ---
    gcs_bucket = os.environ.get("GCS_BUCKET")
    if gcs_bucket:
        job_id = os.environ.get("CLOUD_ML_JOB_ID", "local")
        gcs_upload_dir(adapter_dir, f"{gcs_bucket}/experiments/{job_id}/lora_adapter")

    print("Training complete.")


if __name__ == "__main__":
    main()