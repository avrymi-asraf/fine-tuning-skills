#!/usr/bin/env python3
"""
Prepare a dataset for Gemma 4 E2B fine-tuning.
Loads a HuggingFace dataset, applies the Gemma chat template,
filters by max_seq_length, and saves a formatted dataset ready for training.
"""

import argparse
import os
from datasets import load_dataset
from transformers import AutoTokenizer


def format_conversation(example, tokenizer, max_seq_length):
    """Apply chat template to a single example and add length filter field."""
    messages = example.get("messages") or example.get("conversations")
    if messages is None:
        raise ValueError("Dataset row must contain 'messages' or 'conversations'")

    # Normalize to standard role/content format
    normalized = []
    for turn in messages:
        role = turn.get("role") or turn.get("from")
        content = turn.get("content") or turn.get("value")
        if role == "human":
            role = "user"
        elif role == "gpt":
            role = "assistant"
        normalized.append({"role": role, "content": content})

    text = tokenizer.apply_chat_template(
        normalized,
        tokenize=False,
        add_generation_prompt=False,
    )

    # Tokenize to check length
    token_count = len(tokenizer.encode(text, add_special_tokens=False))
    return {"text": text, "token_count": token_count}


def adapt_alpaca(example):
    """Convert instruction/input/output format to messages format."""
    instruction = example.get("instruction", "")
    input_text = example.get("input", "")
    output = example.get("output", "")
    prompt = instruction if not input_text else f"{instruction}\n{input_text}"
    return {
        "messages": [
            {"role": "user", "content": prompt},
            {"role": "assistant", "content": output},
        ]
    }


def main():
    parser = argparse.ArgumentParser(
        description="Prepare dataset for Gemma 4 E2B fine-tuning"
    )
    parser.add_argument(
        "--dataset_name",
        type=str,
        default="yahma/alpaca-cleaned",
        help="HuggingFace dataset name",
    )
    parser.add_argument(
        "--dataset_config", type=str, default=None, help="Dataset config name"
    )
    parser.add_argument(
        "--split", type=str, default="train", help="Dataset split to use"
    )
    parser.add_argument(
        "--tokenizer_name",
        type=str,
        default="google/gemma-4-E2B-it",
        help="Tokenizer to use for chat templating",
    )
    parser.add_argument(
        "--max_samples",
        type=int,
        default=None,
        help="Limit dataset size for quick experiments",
    )
    parser.add_argument(
        "--max_seq_length",
        type=int,
        default=2048,
        help="Filter out examples exceeding this token count",
    )
    parser.add_argument(
        "--output_path",
        type=str,
        default="data/formatted_dataset",
        help="Where to save the formatted dataset",
    )
    args = parser.parse_args()

    print(f"Loading tokenizer: {args.tokenizer_name}")
    tokenizer = AutoTokenizer.from_pretrained(args.tokenizer_name)

    # Validate chat template exists
    if tokenizer.chat_template is None:
        print(
            f"[WARN] Tokenizer {args.tokenizer_name} has no chat_template. "
            "You may need to specify one manually in the training script."
        )

    print(f"Loading dataset: {args.dataset_name} (split={args.split})")
    ds = load_dataset(args.dataset_name, args.dataset_config, split=args.split)

    if args.max_samples:
        ds = ds.select(range(min(args.max_samples, len(ds))))

    # Adapt format if needed
    if "messages" not in ds.column_names and "conversations" not in ds.column_names:
        print(
            "Dataset lacks 'messages'/'conversations' — adapting from instruction/input/output fields."
        )
        ds = ds.map(adapt_alpaca, remove_columns=ds.column_names)

    print("Applying chat template...")
    ds = ds.map(
        lambda ex: format_conversation(ex, tokenizer, args.max_seq_length),
        remove_columns=ds.column_names,
    )

    # Filter by token length
    before = len(ds)
    ds = ds.filter(lambda ex: ex["token_count"] <= args.max_seq_length)
    after = len(ds)
    removed = before - after
    if removed > 0:
        print(
            f"Filtered out {removed} examples exceeding max_seq_length={args.max_seq_length} "
            f"({before} → {after})"
        )

    # Drop the helper column before saving
    ds = ds.remove_columns(["token_count"])

    print(f"Saving formatted dataset to: {args.output_path}")
    os.makedirs(args.output_path, exist_ok=True)
    ds.save_to_disk(args.output_path)
    print(f"Saved {len(ds)} examples.")


if __name__ == "__main__":
    main()
