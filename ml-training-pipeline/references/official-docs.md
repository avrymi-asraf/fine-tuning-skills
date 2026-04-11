# Official Documentation Links

Core libraries and their primary documentation resources.

## TRL (Transformer Reinforcement Learning)

- **Main Docs**: https://huggingface.co/docs/trl
- **SFTTrainer**: https://huggingface.co/docs/trl/sft_trainer
- **GitHub**: https://github.com/huggingface/trl
- **Examples**: https://github.com/huggingface/trl/tree/main/examples

Key classes:
- `SFTTrainer` - Supervised fine-tuning
- `DPOTrainer` - Direct Preference Optimization
- `PPOTrainer` - Proximal Policy Optimization
- `RewardTrainer` - Reward model training

## Transformers

- **Main Docs**: https://huggingface.co/docs/transformers
- **Trainer**: https://huggingface.co/docs/transformers/main_classes/trainer
- **Training Arguments**: https://huggingface.co/docs/transformers/main_classes/trainer#transformers.TrainingArguments
- **Auto Classes**: https://huggingface.co/docs/transformers/model_doc/auto
- **Chat Templating**: https://huggingface.co/docs/transformers/chat_templating
- **Tool Use**: https://huggingface.co/docs/transformers/chat_extras

## PEFT (Parameter-Efficient Fine-Tuning)

- **Main Docs**: https://huggingface.co/docs/peft
- **Quicktour**: https://huggingface.co/docs/peft/quicktour
- **LoRA Guide**: https://huggingface.co/docs/peft/developer_guides/lora
- **GitHub**: https://github.com/huggingface/peft

Key classes:
- `LoraConfig` - LoRA configuration
- `PeftModel` - PEFT model wrapper
- `get_peft_model` - Apply PEFT to model
- `prepare_model_for_kbit_training` - Prepare for quantization

## Accelerate

- **Main Docs**: https://huggingface.co/docs/accelerate
- **DeepSpeed Integration**: https://huggingface.co/docs/accelerate/usage_guides/deepspeed
- **Multi-GPU**: https://huggingface.co/docs/accelerate/usage_guides/multi_gpu
- **Launch CLI**: https://huggingface.co/docs/accelerate/package_reference/cli

## DeepSpeed

- **Docs**: https://www.deepspeed.ai/docs/
- **Config JSON**: https://www.deepspeed.ai/docs/config-json/
- **ZeRO**: https://www.deepspeed.ai/tutorials/zero/
- **GitHub**: https://github.com/microsoft/DeepSpeed

## Datasets

- **Main Docs**: https://huggingface.co/docs/datasets
- **Loading**: https://huggingface.co/docs/datasets/loading
- **Processing**: https://huggingface.co/docs/datasets/process
- **Streaming**: https://huggingface.co/docs/datasets/stream

## BitsAndBytes (Quantization)

- **GitHub**: https://github.com/TimDettmers/bitsandbytes
- **8-bit**: https://huggingface.co/docs/transformers/main_classes/quantization#bitsandbytes-integration
- **4-bit**: https://huggingface.co/blog/4bit-transformers-bitsandbytes

## Weights & Biases

- **HuggingFace Integration**: https://docs.wandb.ai/guides/integrations/huggingface
- **Transformers**: https://docs.wandb.ai/models/integrations/huggingface_transformers
- **Hyperparameter Tuning**: https://docs.wandb.ai/guides/sweeps

## PyTorch Documentation

- **Main Docs**: https://pytorch.org/docs/stable/index.html
- **DDP**: https://pytorch.org/docs/stable/notes/ddp.html
- **Mixed Precision**: https://pytorch.org/docs/stable/notes/amp_examples.html
- **FSDP**: https://pytorch.org/docs/stable/fsdp.html
- **Profiler**: https://pytorch.org/tutorials/recipes/recipes/profiler_recipe.html

## Flash Attention

- **GitHub**: https://github.com/Dao-AILab/flash-attention
- **Installation**: https://github.com/Dao-AILab/flash-attention#installation-and-features
- **Transformers Integration**: https://huggingface.co/docs/transformers/perf_infer_gpu_one#flashattention-2
