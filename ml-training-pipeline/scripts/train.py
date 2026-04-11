#!/usr/bin/env python3
"""
ML Training Pipeline - Main Training Script
Adaptable template for LLM fine-tuning with TRL, PEFT, and Accelerate.

Usage:
    # Basic training
    python train.py --model_id meta-llama/Llama-2-7b-hf --dataset tatsu-lab/alpaca

    # With LoRA
    python train.py --use_lora --lora_r 32 --learning_rate 1e-4

    # QLoRA (4-bit)
    python train.py --use_qlora --load_in_4bit

    # Multi-GPU with Accelerate
    accelerate launch --num_processes=4 train.py --model_id ...

Environment Variables:
    HF_TOKEN: HuggingFace token for gated models
    WANDB_API_KEY: Weights & Biases API key
    OUTPUT_DIR: Output directory (default: ./results)
"""

import os
import sys
import argparse
import logging
from pathlib import Path
from typing import Optional

import torch
from datasets import load_dataset, Dataset
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    TrainingArguments,
    BitsAndBytesConfig,
    EarlyStoppingCallback,
)
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training, TaskType
from trl import SFTTrainer, DataCollatorForCompletionOnlyLM
from accelerate import Accelerator

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)


def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Fine-tune LLMs with LoRA/QLoRA",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )

    # Model arguments
    parser.add_argument(
        "--model_id",
        type=str,
        default=os.getenv("MODEL_ID", "meta-llama/Llama-2-7b-hf"),
        help="HuggingFace model ID or local path"
    )
    parser.add_argument(
        "--tokenizer_id",
        type=str,
        default=None,
        help="Tokenizer ID (if different from model_id)"
    )
    parser.add_argument(
        "--trust_remote_code",
        action="store_true",
        help="Trust remote code in model/tokenizer"
    )

    # Dataset arguments
    parser.add_argument(
        "--dataset",
        type=str,
        default=os.getenv("DATASET_NAME", "tatsu-lab/alpaca"),
        help="HuggingFace dataset name or local path"
    )
    parser.add_argument(
        "--dataset_config",
        type=str,
        default=None,
        help="Dataset configuration name"
    )
    parser.add_argument(
        "--split",
        type=str,
        default="train",
        help="Dataset split to use"
    )
    parser.add_argument(
        "--text_field",
        type=str,
        default="text",
        help="Field containing text data"
    )
    parser.add_argument(
        "--max_samples",
        type=int,
        default=None,
        help="Maximum number of training samples"
    )

    # Training arguments
    parser.add_argument(
        "--output_dir",
        type=str,
        default=os.getenv("OUTPUT_DIR", "./results"),
        help="Output directory for model and logs"
    )
    parser.add_argument(
        "--num_epochs",
        type=int,
        default=int(os.getenv("NUM_EPOCHS", "3")),
        help="Number of training epochs"
    )
    parser.add_argument(
        "--max_steps",
        type=int,
        default=-1,
        help="Maximum training steps (overrides epochs)"
    )
    parser.add_argument(
        "--batch_size",
        type=int,
        default=int(os.getenv("BATCH_SIZE", "1")),
        help="Per-device batch size"
    )
    parser.add_argument(
        "--gradient_accumulation_steps",
        type=int,
        default=int(os.getenv("GRAD_ACCUM", "8")),
        help="Gradient accumulation steps"
    )
    parser.add_argument(
        "--learning_rate",
        type=float,
        default=float(os.getenv("LEARNING_RATE", "2e-4")),
        help="Learning rate"
    )
    parser.add_argument(
        "--lr_scheduler",
        type=str,
        default="cosine",
        choices=["linear", "cosine", "constant", "polynomial", "inverse_sqrt"],
        help="Learning rate scheduler"
    )
    parser.add_argument(
        "--warmup_ratio",
        type=float,
        default=0.03,
        help="Warmup ratio for learning rate"
    )
    parser.add_argument(
        "--max_seq_length",
        type=int,
        default=int(os.getenv("MAX_SEQ_LENGTH", "2048")),
        help="Maximum sequence length"
    )
    parser.add_argument(
        "--weight_decay",
        type=float,
        default=0.01,
        help="Weight decay"
    )
    parser.add_argument(
        "--max_grad_norm",
        type=float,
        default=1.0,
        help="Max gradient norm for clipping"
    )

    # Precision & Memory
    parser.add_argument(
        "--bf16",
        action="store_true",
        default=True,
        help="Use bfloat16 precision"
    )
    parser.add_argument(
        "--fp16",
        action="store_true",
        help="Use float16 precision (if no BF16 support)"
    )
    parser.add_argument(
        "--gradient_checkpointing",
        action="store_true",
        default=True,
        help="Enable gradient checkpointing"
    )
    parser.add_argument(
        "--attn_implementation",
        type=str,
        default="flash_attention_2",
        choices=["eager", "sdpa", "flash_attention_2"],
        help="Attention implementation"
    )

    # Quantization (QLoRA)
    parser.add_argument(
        "--load_in_4bit",
        action="store_true",
        help="Load model in 4-bit (QLoRA)"
    )
    parser.add_argument(
        "--load_in_8bit",
        action="store_true",
        help="Load model in 8-bit"
    )
    parser.add_argument(
        "--bnb_4bit_compute_dtype",
        type=str,
        default="bfloat16",
        choices=["float16", "bfloat16", "float32"],
        help="Compute dtype for 4-bit quantization"
    )
    parser.add_argument(
        "--bnb_4bit_quant_type",
        type=str,
        default="nf4",
        choices=["nf4", "fp4"],
        help="Quantization type for 4-bit"
    )
    parser.add_argument(
        "--bnb_4bit_use_double_quant",
        action="store_true",
        default=True,
        help="Use nested quantization for 4-bit"
    )

    # LoRA arguments
    parser.add_argument(
        "--use_lora",
        action="store_true",
        help="Use LoRA for parameter-efficient training"
    )
    parser.add_argument(
        "--lora_r",
        type=int,
        default=int(os.getenv("LORA_R", "16")),
        help="LoRA rank"
    )
    parser.add_argument(
        "--lora_alpha",
        type=int,
        default=int(os.getenv("LORA_ALPHA", "32")),
        help="LoRA alpha"
    )
    parser.add_argument(
        "--lora_dropout",
        type=float,
        default=0.05,
        help="LoRA dropout"
    )
    parser.add_argument(
        "--lora_target_modules",
        type=str,
        default=None,
        help="Comma-separated target modules (auto-detected if not specified)"
    )

    # Logging & Checkpointing
    parser.add_argument(
        "--logging_steps",
        type=int,
        default=10,
        help="Log every N steps"
    )
    parser.add_argument(
        "--save_steps",
        type=int,
        default=500,
        help="Save checkpoint every N steps"
    )
    parser.add_argument(
        "--eval_steps",
        type=int,
        default=500,
        help="Evaluate every N steps"
    )
    parser.add_argument(
        "--save_total_limit",
        type=int,
        default=3,
        help="Maximum number of checkpoints to keep"
    )
    parser.add_argument(
        "--eval_dataset",
        type=str,
        default=None,
        help="Evaluation dataset (if separate from training)"
    )
    parser.add_argument(
        "--eval_split",
        type=str,
        default="test",
        help="Evaluation dataset split"
    )

    # Experiment tracking
    parser.add_argument(
        "--report_to",
        type=str,
        default="tensorboard",
        choices=["none", "tensorboard", "wandb", "all"],
        help="Experiment tracking platform"
    )
    parser.add_argument(
        "--run_name",
        type=str,
        default=None,
        help="Run name for experiment tracking"
    )

    # Other
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        help="Random seed"
    )
    parser.add_argument(
        "--dataloader_num_workers",
        type=int,
        default=4,
        help="Number of dataloader workers"
    )
    parser.add_argument(
        "--remove_unused_columns",
        action="store_true",
        default=False,
        help="Remove unused columns from dataset"
    )
    parser.add_argument(
        "--group_by_length",
        action="store_true",
        default=True,
        help="Group sequences by length for efficiency"
    )

    return parser.parse_args()


def load_model_and_tokenizer(args):
    """Load model and tokenizer with appropriate configuration."""
    logger.info(f"Loading model: {args.model_id}")

    tokenizer_id = args.tokenizer_id or args.model_id
    tokenizer = AutoTokenizer.from_pretrained(
        tokenizer_id,
        trust_remote_code=args.trust_remote_code,
        use_fast=True,
    )

    # Set pad token if not present
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
        tokenizer.pad_token_id = tokenizer.eos_token_id

    # Configure quantization
    quantization_config = None
    if args.load_in_4bit:
        logger.info("Loading in 4-bit mode (QLoRA)")
        compute_dtype = getattr(torch, args.bnb_4bit_compute_dtype)
        quantization_config = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_quant_type=args.bnb_4bit_quant_type,
            bnb_4bit_compute_dtype=compute_dtype,
            bnb_4bit_use_double_quant=args.bnb_4bit_use_double_quant,
        )
    elif args.load_in_8bit:
        logger.info("Loading in 8-bit mode")
        quantization_config = BitsAndBytesConfig(load_in_8bit=True)

    # Determine torch dtype
    if quantization_config:
        torch_dtype = torch.float32  # Let BNB handle dtype
    elif args.bf16 and torch.cuda.is_bf16_supported():
        torch_dtype = torch.bfloat16
        logger.info("Using bfloat16 precision")
    elif args.fp16:
        torch_dtype = torch.float16
        logger.info("Using float16 precision")
    else:
        torch_dtype = torch.float32
        logger.info("Using float32 precision")

    # Load model
    model = AutoModelForCausalLM.from_pretrained(
        args.model_id,
        quantization_config=quantization_config,
        torch_dtype=torch_dtype,
        device_map="auto",
        trust_remote_code=args.trust_remote_code,
        attn_implementation=args.attn_implementation,
    )

    return model, tokenizer


def get_lora_config(args, model):
    """Create LoRA configuration."""
    if args.lora_target_modules:
        target_modules = args.lora_target_modules.split(",")
    else:
        # Auto-detect target modules based on model architecture
        model_type = model.config.model_type.lower()
        if model_type in ["llama", "mistral", "qwen2"]:
            target_modules = [
                "q_proj", "k_proj", "v_proj", "o_proj",
                "gate_proj", "up_proj", "down_proj"
            ]
        elif model_type == "gpt2":
            target_modules = ["c_attn", "c_proj", "c_fc"]
        elif model_type == "gptj":
            target_modules = ["q_proj", "v_proj"]
        elif model_type == "gpt_neox":
            target_modules = ["query_key_value", "dense"]
        else:
            logger.warning(f"Unknown model type '{model_type}'. Using default target modules.")
            target_modules = ["q_proj", "v_proj"]

    logger.info(f"Using LoRA target modules: {target_modules}")

    return LoraConfig(
        r=args.lora_r,
        lora_alpha=args.lora_alpha,
        target_modules=target_modules,
        lora_dropout=args.lora_dropout,
        bias="none",
        task_type=TaskType.CAUSAL_LM,
    )


def prepare_dataset(args, tokenizer):
    """Load and prepare dataset."""
    logger.info(f"Loading dataset: {args.dataset}")

    # Load dataset
    if args.dataset_config:
        dataset = load_dataset(args.dataset, args.dataset_config, split=args.split)
    else:
        dataset = load_dataset(args.dataset, split=args.split)

    # Limit samples if specified
    if args.max_samples:
        dataset = dataset.select(range(min(args.max_samples, len(dataset))))

    logger.info(f"Dataset loaded: {len(dataset)} samples")

    # Load eval dataset if specified
    eval_dataset = None
    if args.eval_dataset:
        if args.dataset_config:
            eval_dataset = load_dataset(args.eval_dataset, args.dataset_config, split=args.eval_split)
        else:
            eval_dataset = load_dataset(args.eval_dataset, split=args.eval_split)
        logger.info(f"Eval dataset loaded: {len(eval_dataset)} samples")

    return dataset, eval_dataset


def format_dataset_with_chat_template(dataset, tokenizer, text_field="text"):
    """Apply chat template if the dataset has 'messages' field."""
    if "messages" in dataset.column_names:
        logger.info("Applying chat template to dataset")

        def apply_template(example):
            text = tokenizer.apply_chat_template(
                example["messages"],
                tokenize=False,
                add_generation_prompt=False
            )
            return {text_field: text}

        dataset = dataset.map(apply_template, remove_columns=["messages"])

    return dataset


def main():
    args = parse_args()

    # Set seed
    torch.manual_seed(args.seed)

    # Create output directory
    Path(args.output_dir).mkdir(parents=True, exist_ok=True)

    # Load model and tokenizer
    model, tokenizer = load_model_and_tokenizer(args)

    # Apply LoRA if specified
    peft_config = None
    if args.use_lora or args.load_in_4bit:
        if args.load_in_4bit:
            logger.info("Preparing model for k-bit training")
            model = prepare_model_for_kbit_training(model)

        peft_config = get_lora_config(args, model)
        logger.info(f"Applying LoRA (r={args.lora_r}, alpha={args.lora_alpha})")
        model = get_peft_model(model, peft_config)
        model.print_trainable_parameters()

    # Prepare datasets
    train_dataset, eval_dataset = prepare_dataset(args, tokenizer)
    train_dataset = format_dataset_with_chat_template(train_dataset, tokenizer, args.text_field)
    if eval_dataset:
        eval_dataset = format_dataset_with_chat_template(eval_dataset, tokenizer, args.text_field)

    # Configure training arguments
    training_args = TrainingArguments(
        output_dir=args.output_dir,
        num_train_epochs=args.num_epochs,
        max_steps=args.max_steps if args.max_steps > 0 else None,
        per_device_train_batch_size=args.batch_size,
        per_device_eval_batch_size=args.batch_size,
        gradient_accumulation_steps=args.gradient_accumulation_steps,
        learning_rate=args.learning_rate,
        lr_scheduler_type=args.lr_scheduler,
        warmup_ratio=args.warmup_ratio,
        weight_decay=args.weight_decay,
        max_grad_norm=args.max_grad_norm,
        bf16=args.bf16 and torch.cuda.is_bf16_supported(),
        fp16=args.fp16,
        gradient_checkpointing=args.gradient_checkpointing,
        logging_steps=args.logging_steps,
        logging_dir=f"{args.output_dir}/logs",
        save_strategy="steps",
        save_steps=args.save_steps,
        save_total_limit=args.save_total_limit,
        eval_strategy="steps" if eval_dataset else "no",
        eval_steps=args.eval_steps if eval_dataset else None,
        load_best_model_at_end=True if eval_dataset else False,
        report_to=args.report_to,
        run_name=args.run_name,
        seed=args.seed,
        dataloader_num_workers=args.dataloader_num_workers,
        remove_unused_columns=args.remove_unused_columns,
        group_by_length=args.group_by_length,
        optim="paged_adamw_8bit" if args.load_in_4bit else "adamw_torch_fused",
    )

    # Initialize trainer
    trainer = SFTTrainer(
        model=model,
        tokenizer=tokenizer,
        train_dataset=train_dataset,
        eval_dataset=eval_dataset,
        peft_config=peft_config if not args.load_in_4bit else None,  # Already applied
        max_seq_length=args.max_seq_length,
        dataset_text_field=args.text_field,
        args=training_args,
        callbacks=[EarlyStoppingCallback(early_stopping_patience=3)] if eval_dataset else None,
    )

    # Train
    logger.info("Starting training...")
    trainer.train()

    # Save final model
    logger.info(f"Saving model to {args.output_dir}")
    trainer.save_model(args.output_dir)
    tokenizer.save_pretrained(args.output_dir)

    # Save training config
    import json
    config_path = Path(args.output_dir) / "training_config.json"
    with open(config_path, "w") as f:
        json.dump(vars(args), f, indent=2, default=str)

    logger.info("Training complete!")


if __name__ == "__main__":
    main()
