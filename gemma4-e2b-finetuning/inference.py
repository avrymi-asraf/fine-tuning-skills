#!/usr/bin/env python3
"""
Quick local inference script for the fine-tuned Gemma 4 E2B model.
Supports loading merged models, LoRA adapters, or base models.
"""

import argparse
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
from peft import PeftModel


def load_model_and_tokenizer(model_path, adapter_path=None, load_in_4bit=True):
    tokenizer = AutoTokenizer.from_pretrained(model_path)
    tokenizer.pad_token = tokenizer.eos_token
    tokenizer.padding_side = "left"  # Better for generation

    if adapter_path:
        # Load base model then merge adapter
        bnb_config = None
        if load_in_4bit:
            bnb_config = BitsAndBytesConfig(
                load_in_4bit=True,
                bnb_4bit_quant_type="nf4",
                bnb_4bit_compute_dtype=torch.bfloat16,
                bnb_4bit_use_double_quant=True,
            )
        model = AutoModelForCausalLM.from_pretrained(
            model_path,
            quantization_config=bnb_config,
            device_map="auto",
            attn_implementation="eager",
        )
        model = PeftModel.from_pretrained(model, adapter_path)
        model = model.merge_and_unload()  # Merge for faster inference
    else:
        model = AutoModelForCausalLM.from_pretrained(
            model_path,
            device_map="auto",
            torch_dtype=torch.bfloat16 if torch.cuda.is_available() else torch.float32,
            attn_implementation="eager",
        )

    return model, tokenizer


def generate(model, tokenizer, messages, max_new_tokens=256, temperature=0.7, top_p=0.9):
    inputs = tokenizer.apply_chat_template(
        messages,
        tokenize=True,
        return_tensors="pt",
        add_generation_prompt=True,
    ).to(model.device)

    with torch.no_grad():
        outputs = model.generate(
            inputs,
            max_new_tokens=max_new_tokens,
            do_sample=True,
            temperature=temperature,
            top_p=top_p,
            pad_token_id=tokenizer.eos_token_id,
        )

    # Decode only the newly generated tokens
    response = tokenizer.decode(outputs[0][inputs.shape[1]:], skip_special_tokens=True)
    return response.strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model_path", type=str, required=True,
                        help="Path to base model or merged model")
    parser.add_argument("--adapter_path", type=str, default=None,
                        help="Path to LoRA adapter (optional)")
    parser.add_argument("--load_in_4bit", action="store_true", default=True,
                        help="Load base model in 4-bit when using adapter")
    parser.add_argument("--max_new_tokens", type=int, default=256)
    parser.add_argument("--temperature", type=float, default=0.7)
    args = parser.parse_args()

    print(f"Loading model from: {args.model_path}")
    if args.adapter_path:
        print(f"With adapter: {args.adapter_path}")

    model, tokenizer = load_model_and_tokenizer(
        args.model_path,
        args.adapter_path,
        args.load_in_4bit,
    )

    print("\nEnter your prompts. Type 'quit' to exit.\n")
    while True:
        user_input = input("User: ")
        if user_input.lower() in ("quit", "exit"):
            break

        messages = [{"role": "user", "content": user_input}]
        response = generate(
            model, tokenizer, messages,
            max_new_tokens=args.max_new_tokens,
            temperature=args.temperature,
        )
        print(f"Assistant: {response}\n")


if __name__ == "__main__":
    main()
