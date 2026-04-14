#!/usr/bin/env python3
"""
Primary training script for Gemma 4 E2B using Unsloth + LoRA.
Supports: local training, Vertex AI custom jobs, GCS I/O, checkpoint resumption.
"""

import argparse
import os
import yaml
import torch
from datasets import load_from_disk
from transformers import TrainingArguments
from trl import SFTTrainer
from unsloth import FastLanguageModel


# ---------------------------------------------------------------------------
# GCS helpers — download/upload via google-cloud-storage when running on
# Vertex AI. Falls back to local paths when GCS_BUCKET is not set.
# ---------------------------------------------------------------------------
def _gcs_client():
    """Lazy GCS client; returns None if google-cloud-storage is missing."""
    try:
        from google.cloud import storage
        return storage.Client()
    except ImportError:
        return None


def gcs_download_dir(gcs_uri: str, local_dir: str) -> str:
    """Download a GCS prefix to a local directory. No-op if not a gs:// URI."""
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
    """Upload a local directory to a GCS prefix. No-op if not a gs:// URI."""
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


# ---------------------------------------------------------------------------
# Resolve output directory from Vertex AI AIP env vars or fallback
# ---------------------------------------------------------------------------
def resolve_output_dir(cli_arg: str) -> str:
    """AIP_MODEL_DIR takes precedence (set by Vertex AI at runtime)."""
    aip_dir = os.environ.get("AIP_MODEL_DIR")
    if aip_dir:
        # Vertex AI mounts this as a local path backed by GCS
        return aip_dir
    return cli_arg


def resolve_checkpoint_dir(output_dir: str) -> str:
    """Return AIP checkpoint dir if set, otherwise the output dir."""
    return os.environ.get("AIP_CHECKPOINT_DIR", output_dir)


# ---------------------------------------------------------------------------
# Checkpoint resumption
# ---------------------------------------------------------------------------
def find_last_checkpoint(output_dir: str) -> str | None:
    """Find the latest checkpoint in the output directory."""
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
    parser = argparse.ArgumentParser(description="Gemma 4 E2B Unsloth LoRA training")
    parser.add_argument("--config", type=str, default="configs/unsloth_lora.yaml",
                        help="Path to YAML config")
    parser.add_argument("--dataset_path", type=str, default="data/formatted_dataset",
                        help="Local path or gs:// URI to dataset")
    parser.add_argument("--output_dir", type=str, default="outputs/unsloth-gemma4-e2b",
                        help="Local output dir (overridden by AIP_MODEL_DIR on Vertex AI)")
    args = parser.parse_args()

    cfg = load_config(args.config)

    # --- Resolve paths ---
    output_dir = resolve_output_dir(args.output_dir)
    dataset_path = args.dataset_path

    # If dataset is on GCS, download it locally first
    if dataset_path.startswith("gs://"):
        dataset_path = gcs_download_dir(dataset_path, "/tmp/dataset")

    model_name = cfg["model_name"]
    max_seq_length = cfg["max_seq_length"]

    # --- HF auth (for gated models) ---
    hf_token = os.environ.get("HF_TOKEN")
    if hf_token:
        from huggingface_hub import login
        login(token=hf_token)

    # --- Load model ---
    print(f"Loading model: {model_name}")
    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=model_name,
        max_seq_length=max_seq_length,
        dtype=None,
        load_in_4bit=cfg.get("load_in_4bit", True),
    )

    # --- Add LoRA adapters ---
    print("Adding LoRA adapters...")
    model = FastLanguageModel.get_peft_model(
        model,
        r=cfg["lora_r"],
        target_modules=cfg["target_modules"],
        lora_alpha=cfg["lora_alpha"],
        lora_dropout=cfg["lora_dropout"],
        bias="none",
        use_gradient_checkpointing=cfg.get("gradient_checkpointing", "unsloth"),
        random_state=cfg["seed"],
        use_rslora=cfg.get("use_rslora", False),
    )

    # --- Load dataset ---
    print(f"Loading dataset from: {dataset_path}")
    dataset = load_from_disk(dataset_path)

    # --- Checkpoint resumption ---
    checkpoint_dir = resolve_checkpoint_dir(output_dir)
    last_checkpoint = find_last_checkpoint(checkpoint_dir)
    if last_checkpoint:
        print(f"Resuming from checkpoint: {last_checkpoint}")
    elif os.path.isdir(checkpoint_dir) and checkpoint_dir != output_dir:
        # AIP checkpoint dir exists but no checkpoint subdir yet — check output_dir too
        last_checkpoint = find_last_checkpoint(output_dir)
        if last_checkpoint:
            print(f"Resuming from checkpoint: {last_checkpoint}")

    # --- Training args ---
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
        optim=cfg.get("optim", "adamw_8bit"),
        weight_decay=cfg["weight_decay"],
        lr_scheduler_type=cfg["lr_scheduler_type"],
        seed=cfg["seed"],
        report_to=cfg.get("report_to", "none"),
        # Checkpointing (essential for Spot VM preemption recovery)
        save_strategy=cfg.get("save_strategy", "steps"),
        save_steps=cfg.get("save_steps", 100),
        save_total_limit=cfg.get("save_total_limit", 3),
    )

    # --- Train ---
    trainer = SFTTrainer(
        model=model,
        tokenizer=tokenizer,
        train_dataset=dataset,
        dataset_text_field="text",
        max_seq_length=max_seq_length,
        args=training_args,
    )

    print("Starting training...")
    trainer.train(resume_from_checkpoint=last_checkpoint)

    # --- Save adapter ---
    adapter_dir = os.path.join(output_dir, "lora_adapter")
    print(f"Saving LoRA adapter to {adapter_dir}")
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