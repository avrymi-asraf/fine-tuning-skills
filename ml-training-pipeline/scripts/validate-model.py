#!/usr/bin/env python3
"""
Model Validation Script
Quick inference test for trained models.

Usage:
    # Test base model
    python validate-model.py --model_path meta-llama/Llama-2-7b-hf

    # Test fine-tuned LoRA model
    python validate-model.py --model_path ./results/checkpoint-1000 --base_model meta-llama/Llama-2-7b-hf

    # Interactive mode
    python validate-model.py --model_path ./results --interactive

    # Batch test from file
    python validate-model.py --model_path ./results --test_file prompts.txt
"""

import os
import sys
import json
import argparse
import logging
from pathlib import Path
from typing import List, Dict, Any

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
from peft import PeftModel

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description="Validate fine-tuned models")

    # Model
    parser.add_argument("--model_path", type=str, required=True, help="Path to model or checkpoint")
    parser.add_argument("--base_model", type=str, default=None, help="Base model for LoRA")
    parser.add_argument("--load_in_4bit", action="store_true", help="Load in 4-bit")
    parser.add_argument("--load_in_8bit", action="store_true", help="Load in 8-bit")

    # Generation
    parser.add_argument("--max_new_tokens", type=int, default=256, help="Max tokens to generate")
    parser.add_argument("--temperature", type=float, default=0.7, help="Sampling temperature")
    parser.add_argument("--top_p", type=float, default=0.9, help="Top-p sampling")
    parser.add_argument("--top_k", type=int, default=50, help="Top-k sampling")
    parser.add_argument("--repetition_penalty", type=float, default=1.0, help="Repetition penalty")

    # Test inputs
    parser.add_argument("--prompt", type=str, default=None, help="Single prompt to test")
    parser.add_argument("--test_file", type=str, default=None, help="File with test prompts (one per line)")
    parser.add_argument("--system_prompt", type=str, default=None, help="System prompt")
    parser.add_argument("--interactive", action="store_true", help="Interactive mode")

    # Output
    parser.add_argument("--output", type=str, default=None, help="Output file for results")
    parser.add_argument("--format", type=str, default="text", choices=["text", "json"], help="Output format")

    return parser.parse_args()


def load_model(model_path: str, base_model: str = None, load_in_4bit: bool = False, load_in_8bit: bool = False):
    """Load model and tokenizer."""
    logger.info(f"Loading model from: {model_path}")

    # Determine if it's a PEFT model
    is_peft = (Path(model_path) / "adapter_config.json").exists()

    if is_peft:
        if not base_model:
            # Try to read base model from adapter config
            import json
            with open(Path(model_path) / "adapter_config.json") as f:
                config = json.load(f)
                base_model = config.get("base_model_name_or_path", config.get("_name_or_path"))
            logger.info(f"Detected LoRA model, using base: {base_model}")

    # Configure quantization
    quantization_config = None
    if load_in_4bit:
        quantization_config = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_compute_dtype=torch.bfloat16,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_use_double_quant=True,
        )
    elif load_in_8bit:
        quantization_config = BitsAndBytesConfig(load_in_8bit=True)

    # Load tokenizer
    tokenizer = AutoTokenizer.from_pretrained(base_model if is_peft else model_path)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    # Load base model
    model = AutoModelForCausalLM.from_pretrained(
        base_model if is_peft else model_path,
        quantization_config=quantization_config,
        device_map="auto",
        torch_dtype=torch.bfloat16 if not quantization_config else torch.float32,
        attn_implementation="sdpa",
    )

    # Load PEFT adapter if applicable
    if is_peft:
        logger.info("Loading PEFT adapter...")
        model = PeftModel.from_pretrained(model, model_path)
        model = model.merge_and_unload()  # Merge for faster inference

    model.eval()

    return model, tokenizer


def format_prompt(prompt: str, tokenizer, system_prompt: str = None) -> str:
    """Format prompt with chat template if available."""
    if system_prompt:
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": prompt}
        ]
    else:
        messages = [{"role": "user", "content": prompt}]

    try:
        formatted = tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True
        )
    except:
        # Fallback to simple formatting
        formatted = prompt if not system_prompt else f"System: {system_prompt}\n\nUser: {prompt}\n\nAssistant:"

    return formatted


def generate(model, tokenizer, prompt: str, args) -> str:
    """Generate response for a prompt."""
    inputs = tokenizer(prompt, return_tensors="pt", truncation=True, max_length=2048)
    inputs = {k: v.to(model.device) for k, v in inputs.items()}

    with torch.no_grad():
        outputs = model.generate(
            **inputs,
            max_new_tokens=args.max_new_tokens,
            temperature=args.temperature,
            top_p=args.top_p,
            top_k=args.top_k,
            repetition_penalty=args.repetition_penalty,
            do_sample=True,
            pad_token_id=tokenizer.pad_token_id,
            eos_token_id=tokenizer.eos_token_id,
        )

    # Decode only new tokens
    input_length = inputs["input_ids"].shape[1]
    generated_tokens = outputs[0][input_length:]
    response = tokenizer.decode(generated_tokens, skip_special_tokens=True)

    return response.strip()


def interactive_mode(model, tokenizer, args):
    """Run interactive chat mode."""
    print("\n" + "="*50)
    print("Interactive Mode - Type 'quit' to exit, 'clear' to reset")
    print("="*50 + "\n")

    conversation_history = []

    while True:
        try:
            user_input = input("\nUser: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nExiting...")
            break

        if user_input.lower() in ["quit", "exit", "q"]:
            break

        if user_input.lower() == "clear":
            conversation_history = []
            print("Conversation history cleared.")
            continue

        if not user_input:
            continue

        # Format with history
        messages = []
        if args.system_prompt:
            messages.append({"role": "system", "content": args.system_prompt})

        for user_msg, assistant_msg in conversation_history:
            messages.append({"role": "user", "content": user_msg})
            messages.append({"role": "assistant", "content": assistant_msg})

        messages.append({"role": "user", "content": user_input})

        try:
            prompt = tokenizer.apply_chat_template(
                messages,
                tokenize=False,
                add_generation_prompt=True
            )
        except:
            prompt = user_input

        response = generate(model, tokenizer, prompt, args)
        print(f"\nAssistant: {response}")

        conversation_history.append((user_input, response))


def run_tests(model, tokenizer, prompts: List[str], args) -> List[Dict[str, str]]:
    """Run tests on a list of prompts."""
    results = []

    for i, prompt in enumerate(prompts, 1):
        logger.info(f"Testing {i}/{len(prompts)}...")

        formatted_prompt = format_prompt(prompt, tokenizer, args.system_prompt)
        response = generate(model, tokenizer, formatted_prompt, args)

        results.append({
            "prompt": prompt,
            "response": response
        })

        if args.format == "text":
            print(f"\n{'='*50}")
            print(f"Prompt: {prompt[:100]}..." if len(prompt) > 100 else f"Prompt: {prompt}")
            print(f"{'-'*50}")
            print(f"Response: {response[:200]}..." if len(response) > 200 else f"Response: {response}")
            print(f"{'='*50}")

    return results


def main():
    args = parse_args()

    # Load model
    model, tokenizer = load_model(
        args.model_path,
        args.base_model,
        args.load_in_4bit,
        args.load_in_8bit
    )

    # Determine test prompts
    prompts = []
    if args.prompt:
        prompts = [args.prompt]
    elif args.test_file:
        with open(args.test_file) as f:
            prompts = [line.strip() for line in f if line.strip()]
    else:
        # Default test prompts
        prompts = [
            "What is machine learning?",
            "Explain the concept of fine-tuning in simple terms.",
            "Write a short poem about artificial intelligence.",
        ]

    # Run tests or interactive mode
    if args.interactive:
        interactive_mode(model, tokenizer, args)
    else:
        results = run_tests(model, tokenizer, prompts, args)

        # Save results
        if args.output:
            with open(args.output, "w") as f:
                if args.format == "json":
                    json.dump(results, f, indent=2)
                else:
                    for r in results:
                        f.write(f"Prompt: {r['prompt']}\n")
                        f.write(f"Response: {r['response']}\n")
                        f.write("-" * 50 + "\n")
            logger.info(f"Results saved to: {args.output}")

    logger.info("Validation complete!")


if __name__ == "__main__":
    main()
