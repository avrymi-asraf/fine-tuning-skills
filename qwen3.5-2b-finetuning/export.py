#!/usr/bin/env python3
"""
Export the fine-tuned Qwen 3.5 2B model.
Supports:
  - Saving LoRA adapter
  - Merging adapters to 16-bit HF model
  - Exporting to GGUF (Q4_K_M, Q8_0) via Unsloth
"""

import argparse
import os
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel


def save_adapter(model, tokenizer, output_path):
    os.makedirs(output_path, exist_ok=True)
    model.save_pretrained(output_path)
    tokenizer.save_pretrained(output_path)
    print(f"Adapter saved to: {output_path}")


def merge_and_save(model_path, adapter_path, output_path):
    print(f"Loading base model from: {model_path}")
    model = AutoModelForCausalLM.from_pretrained(
        model_path,
        torch_dtype=torch.bfloat16,
        device_map="auto",
        attn_implementation="eager",
    )
    tokenizer = AutoTokenizer.from_pretrained(model_path)

    print(f"Loading adapter from: {adapter_path}")
    model = PeftModel.from_pretrained(model, adapter_path)

    print("Merging adapter into base model...")
    model = model.merge_and_unload()

    os.makedirs(output_path, exist_ok=True)
    model.save_pretrained(output_path)
    tokenizer.save_pretrained(output_path)
    print(f"Merged model saved to: {output_path}")


def export_gguf_unsloth(adapter_path, output_dir, quantization_methods):
    try:
        from unsloth import FastLanguageModel
    except ImportError:
        print("Unsloth not installed. Skipping GGUF export.")
        return

    print(f"Loading model for GGUF export from: {adapter_path}")
    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=adapter_path,
        max_seq_length=2048,
        dtype=None,
        load_in_4bit=False,
    )

    os.makedirs(output_dir, exist_ok=True)
    for method in quantization_methods:
        print(f"Exporting GGUF with quantization: {method}")
        model.save_pretrained_gguf(
            output_dir,
            tokenizer,
            quantization_method=method,
        )
    print(f"GGUF exports saved to: {output_dir}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", type=str, required=True,
                        choices=["adapter", "merge", "gguf", "all"],
                        help="Export mode")
    parser.add_argument("--model_path", type=str, default="Qwen/Qwen3.5-2B",
                        help="Base model path (for merge)")
    parser.add_argument("--adapter_path", type=str, required=True,
                        help="Path to LoRA adapter")
    parser.add_argument("--output_dir", type=str, default="exports",
                        help="Output directory")
    parser.add_argument("--gguf_methods", nargs="+", default=["q4_k_m", "q8_0"],
                        help="GGUF quantization methods")
    args = parser.parse_args()

    if args.mode in ("adapter", "all"):
        # adapter_path is itself the adapter; just re-save it cleanly
        tokenizer = AutoTokenizer.from_pretrained(args.adapter_path)
        model = AutoModelForCausalLM.from_pretrained(
            args.model_path,
            torch_dtype=torch.bfloat16,
            device_map="auto",
            attn_implementation="eager",
        )
        model = PeftModel.from_pretrained(model, args.adapter_path)
        save_adapter(model, tokenizer, os.path.join(args.output_dir, "lora_adapter"))

    if args.mode in ("merge", "all"):
        merge_and_save(
            args.model_path,
            args.adapter_path,
            os.path.join(args.output_dir, "merged_16bit"),
        )

    if args.mode in ("gguf", "all"):
        export_gguf_unsloth(
            args.adapter_path,
            os.path.join(args.output_dir, "gguf"),
            args.gguf_methods,
        )

    print("Export complete.")


if __name__ == "__main__":
    main()
