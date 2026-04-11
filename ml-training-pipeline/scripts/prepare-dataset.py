#!/usr/bin/env python3
"""
Dataset Preparation Script
Handles loading, formatting, and preprocessing datasets for fine-tuning.

Usage:
    # Convert Alpaca format to chat format
    python prepare-dataset.py --dataset tatsu-lab/alpaca --output ./data/alpaca-chat.jsonl

    # Convert with custom template
    python prepare-dataset.py --dataset json --data_files ./raw/data.json --format conversation

    # Prepare dataset with train/val split
    python prepare-dataset.py --dataset json --train_file train.jsonl --val_file val.jsonl --output ./data/processed
"""

import os
import sys
import json
import argparse
import logging
from pathlib import Path
from typing import Dict, List, Any, Optional
from dataclasses import dataclass

from datasets import load_dataset, Dataset, DatasetDict, concatenate_datasets
from transformers import AutoTokenizer

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


@dataclass
class FormatConfig:
    """Configuration for dataset formatting."""
    name: str
    system_prompt: Optional[str] = None
    input_template: str = "{input}"
    output_template: str = "{output}"
    instruction_template: str = "{instruction}"


# Common format presets
FORMATS = {
    "alpaca": FormatConfig(
        name="alpaca",
        system_prompt=None,
        instruction_template="### Instruction:\n{instruction}\n\n",
        input_template="### Input:\n{input}\n\n" if "{input}" else "",
        output_template="### Response:\n{output}"
    ),
    "chat": FormatConfig(
        name="chat",
        system_prompt=None,  # Will be constructed from messages
    ),
    "sharegpt": FormatConfig(
        name="sharegpt",
    ),
    "oasst": FormatConfig(
        name="oasst",
    ),
}


def parse_args():
    parser = argparse.ArgumentParser(description="Prepare datasets for fine-tuning")

    # Input
    parser.add_argument("--dataset", type=str, required=True, help="Dataset name or path")
    parser.add_argument("--dataset_config", type=str, default=None, help="Dataset config")
    parser.add_argument("--split", type=str, default="train", help="Dataset split")
    parser.add_argument("--data_files", type=str, nargs="+", help="Data file paths")
    parser.add_argument("--train_file", type=str, help="Training file path")
    parser.add_argument("--val_file", type=str, help="Validation file path")
    parser.add_argument("--test_file", type=str, help="Test file path")
    parser.add_argument("--text_field", type=str, default="text", help="Text field name")

    # Formatting
    parser.add_argument("--format", type=str, default="chat", choices=["alpaca", "chat", "sharegpt", "raw", "custom"], help="Output format")
    parser.add_argument("--tokenizer", type=str, default=None, help="Tokenizer for chat template")
    parser.add_argument("--system_prompt", type=str, default=None, help="System prompt to prepend")
    parser.add_argument("--add_generation_prompt", action="store_true", help="Add generation prompt")

    # Processing
    parser.add_argument("--max_samples", type=int, default=None, help="Max samples to process")
    parser.add_argument("--min_length", type=int, default=10, help="Minimum sequence length")
    parser.add_argument("--max_length", type=int, default=8192, help="Maximum sequence length")
    parser.add_argument("--filter_empty", action="store_true", default=True, help="Filter empty examples")
    parser.add_argument("--deduplicate", action="store_true", help="Remove duplicates")

    # Output
    parser.add_argument("--output", type=str, required=True, help="Output path")
    parser.add_argument("--output_format", type=str, default="jsonl", choices=["jsonl", "json", "parquet", "hf"], help="Output format")
    parser.add_argument("--train_split", type=float, default=0.9, help="Training split ratio")
    parser.add_argument("--val_split", type=float, default=0.1, help="Validation split ratio")
    parser.add_argument("--seed", type=int, default=42, help="Random seed")

    return parser.parse_args()


def load_source_dataset(args) -> DatasetDict:
    """Load dataset from various sources."""
    if args.data_files:
        logger.info(f"Loading from files: {args.data_files}")
        dataset = load_dataset("json", data_files=args.data_files)
    elif args.train_file or args.val_file:
        data_files = {}
        if args.train_file:
            data_files["train"] = args.train_file
        if args.val_file:
            data_files["validation"] = args.val_file
        if args.test_file:
            data_files["test"] = args.test_file
        dataset = load_dataset("json", data_files=data_files)
    else:
        logger.info(f"Loading dataset: {args.dataset}")
        if args.dataset_config:
            dataset = load_dataset(args.dataset, args.dataset_config)
        else:
            dataset = load_dataset(args.dataset)

    # Handle single split datasets
    if isinstance(dataset, Dataset):
        dataset = DatasetDict({"train": dataset})

    return dataset


def format_as_alpaca(example: Dict[str, Any]) -> Dict[str, str]:
    """Format example in Alpaca style."""
    instruction = example.get("instruction", "")
    input_text = example.get("input", "")
    output = example.get("output", "")

    if input_text:
        text = f"### Instruction:\n{instruction}\n\n### Input:\n{input_text}\n\n### Response:\n{output}"
    else:
        text = f"### Instruction:\n{instruction}\n\n### Response:\n{output}"

    return {"text": text}


def format_as_chat(example: Dict[str, Any], tokenizer=None) -> Dict[str, Any]:
    """Format example as chat messages."""
    # If already in messages format, return as-is
    if "messages" in example:
        return example

    # Convert from instruction format
    messages = []
    if "system" in example:
        messages.append({"role": "system", "content": example["system"]})
    elif "instruction" in example:
        # Single-turn conversation
        messages.append({"role": "user", "content": example["instruction"]})
        if "input" in example and example["input"]:
            messages[-1]["content"] += f"\n\n{example['input']}"
        messages.append({"role": "assistant", "content": example.get("output", "")})
    elif "conversations" in example:
        # ShareGPT-style
        messages = [
            {"role": "user" if turn["from"] == "human" else "assistant", "content": turn["value"]}
            for turn in example["conversations"]
        ]
    elif "question" in example and "answer" in example:
        messages = [
            {"role": "user", "content": example["question"]},
            {"role": "assistant", "content": example["answer"]}
        ]

    return {"messages": messages}


def apply_chat_template(example: Dict[str, Any], tokenizer, add_generation_prompt: bool = False) -> Dict[str, str]:
    """Apply tokenizer's chat template to messages."""
    if "messages" not in example:
        return example

    text = tokenizer.apply_chat_template(
        example["messages"],
        tokenize=False,
        add_generation_prompt=add_generation_prompt
    )
    return {"text": text}


def format_dataset(dataset: Dataset, format_type: str, tokenizer=None, system_prompt: str = None, add_generation_prompt: bool = False) -> Dataset:
    """Format dataset to specified format."""
    logger.info(f"Formatting dataset to {format_type} format")

    if format_type == "alpaca":
        dataset = dataset.map(format_as_alpaca, remove_columns=dataset.column_names)

    elif format_type == "chat":
        dataset = dataset.map(format_as_chat, remove_columns=dataset.column_names)
        if tokenizer:
            dataset = dataset.map(
                lambda x: apply_chat_template(x, tokenizer, add_generation_prompt),
                remove_columns=["messages"] if not add_generation_prompt else []
            )

    elif format_type == "sharegpt":
        def convert_sharegpt(example):
            if "conversations" in example:
                messages = []
                for turn in example["conversations"]:
                    role = "user" if turn.get("from") in ["human", "user", "gpt"] else "assistant"
                    if turn.get("from") == "gpt":
                        role = "assistant"
                    messages.append({"role": role, "content": turn.get("value", "")})
                return {"messages": messages}
            return example
        dataset = dataset.map(convert_sharegpt)

    # Add system prompt if specified
    if system_prompt and "text" in dataset.column_names:
        def add_system(example):
            example["text"] = f"<|system|>\n{system_prompt}\n{example['text']}"
            return example
        dataset = dataset.map(add_system)

    return dataset


def filter_dataset(dataset: Dataset, min_length: int, max_length: int, tokenizer=None) -> Dataset:
    """Filter dataset by length and quality."""
    initial_count = len(dataset)

    # Filter empty examples
    def is_not_empty(example):
        text = example.get("text", "")
        if not text:
            text = str(example.get("messages", ""))
        return len(text.strip()) > min_length

    dataset = dataset.filter(is_not_empty)

    # Filter by token length if tokenizer provided
    if tokenizer and "text" in dataset.column_names:
        def is_valid_length(example):
            tokens = tokenizer.encode(example["text"], add_special_tokens=False)
            return min_length <= len(tokens) <= max_length

        dataset = dataset.filter(is_valid_length)

    final_count = len(dataset)
    logger.info(f"Filtered: {initial_count} -> {final_count} examples")

    return dataset


def deduplicate_dataset(dataset: Dataset, text_field: str = "text") -> Dataset:
    """Remove duplicate examples."""
    logger.info("Removing duplicates...")
    initial_count = len(dataset)

    seen = set()
    def is_unique(example):
        text = example.get(text_field, str(example))
        text_hash = hash(text)
        if text_hash in seen:
            return False
        seen.add(text_hash)
        return True

    dataset = dataset.filter(is_unique)
    final_count = len(dataset)
    logger.info(f"Deduplicated: {initial_count} -> {final_count} examples")

    return dataset


def split_dataset(dataset: Dataset, train_ratio: float, val_ratio: float, seed: int) -> DatasetDict:
    """Split dataset into train/validation/test sets."""
    test_ratio = 1 - train_ratio - val_ratio

    # First split: train and temp (val + test)
    train_temp = dataset.train_test_split(test_size=(1 - train_ratio), seed=seed)
    train_ds = train_temp["train"]
    temp_ds = train_temp["test"]

    if test_ratio > 0:
        # Second split: val and test
        val_test = temp_ds.train_test_split(test_size=test_ratio / (val_ratio + test_ratio), seed=seed)
        return DatasetDict({
            "train": train_ds,
            "validation": val_test["train"],
            "test": val_test["test"]
        })
    else:
        return DatasetDict({
            "train": train_ds,
            "validation": temp_ds
        })


def save_dataset(dataset: DatasetDict, output_path: str, format: str):
    """Save dataset to specified format."""
    output_path = Path(output_path)
    output_path.mkdir(parents=True, exist_ok=True)

    logger.info(f"Saving dataset to {output_path} as {format}")

    if format == "jsonl":
        for split, ds in dataset.items():
            file_path = output_path / f"{split}.jsonl"
            ds.to_json(str(file_path), lines=True, force_ascii=False)
            logger.info(f"Saved {split}: {len(ds)} examples to {file_path}")

    elif format == "json":
        for split, ds in dataset.items():
            file_path = output_path / f"{split}.json"
            ds.to_json(str(file_path), force_ascii=False)

    elif format == "parquet":
        for split, ds in dataset.items():
            file_path = output_path / f"{split}.parquet"
            ds.to_parquet(str(file_path))

    elif format == "hf":
        dataset.save_to_disk(str(output_path))
        logger.info(f"Saved HuggingFace dataset to {output_path}")


def main():
    args = parse_args()

    # Load dataset
    dataset = load_source_dataset(args)
    logger.info(f"Loaded dataset splits: {list(dataset.keys())}")

    # Get the main split for processing
    if "train" in dataset:
        main_dataset = dataset["train"]
    else:
        main_dataset = dataset[list(dataset.keys())[0]]

    # Limit samples
    if args.max_samples:
        main_dataset = main_dataset.select(range(min(args.max_samples, len(main_dataset))))

    # Load tokenizer if needed for chat template
    tokenizer = None
    if args.tokenizer:
        logger.info(f"Loading tokenizer: {args.tokenizer}")
        tokenizer = AutoTokenizer.from_pretrained(args.tokenizer)

    # Format dataset
    main_dataset = format_dataset(
        main_dataset,
        args.format,
        tokenizer=tokenizer,
        system_prompt=args.system_prompt,
        add_generation_prompt=args.add_generation_prompt
    )

    # Filter
    main_dataset = filter_dataset(main_dataset, args.min_length, args.max_length, tokenizer)

    # Deduplicate
    if args.deduplicate:
        main_dataset = deduplicate_dataset(main_dataset, args.text_field)

    # Create splits if needed
    if len(dataset) == 1 and not args.val_file:
        logger.info(f"Creating train/val split ({args.train_split}/{args.val_split})")
        dataset = split_dataset(main_dataset, args.train_split, args.val_split, args.seed)
    else:
        dataset = DatasetDict({"train": main_dataset})
        if "validation" in locals():
            dataset["validation"] = locals()["validation"]

    # Save
    save_dataset(dataset, args.output, args.output_format)

    # Print stats
    logger.info("\nDataset Statistics:")
    for split, ds in dataset.items():
        logger.info(f"  {split}: {len(ds)} examples")
        if "text" in ds.column_names:
            lengths = [len(text) for text in ds["text"]]
            logger.info(f"    Avg length: {sum(lengths) / len(lengths):.0f} chars")

    logger.info(f"\nDataset saved to: {args.output}")


if __name__ == "__main__":
    main()
