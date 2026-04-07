#!/bin/bash
#
# gcp_gemma.sh - Gemma 4 specific workflows for fine-tuning and inference
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DEFAULT_OUTPUT_DIR="$HOME/gemma-output"
DEFAULT_DATA_DIR="$HOME/data"

show_help() {
    cat << EOF
Usage: $(basename "$0") <command> [options]

Commands:
  download <model> [options]    Download a Gemma model from HuggingFace
  finetune [options]            Run fine-tuning with Unsloth
  serve <model> [options]       Start inference server
  convert <path> [options]      Convert model to different formats

Model names:
  unsloth/gemma-4-4b            Gemma 4 4B (recommended for T4/L4)
  unsloth/gemma-4-26b           Gemma 4 26B (needs A100 80GB)
  unsloth/gemma-4-31b           Gemma 4 31B (needs A100 80GB)
  unsloth/gemma-4-e2b           Gemma 4 E2B (smallest, fits anywhere)

Options for finetune:
  --model=<name>                Model name (default: unsloth/gemma-4-4b)
  --dataset=<path>              Path to training dataset (JSONL format)
  --output=<path>               Output directory (default: ~/gemma-output)
  --epochs=<n>                  Number of training epochs (default: 3)
  --batch-size=<n>              Batch size (default: 2)
  --learning-rate=<rate>        Learning rate (default: 2e-4)
  --max-seq-length=<n>          Max sequence length (default: 2048)
  --4bit                        Use 4-bit quantization (saves VRAM)
  --8bit                        Use 8-bit quantization

Options for serve:
  --backend=<backend>           Backend: vllm, ollama, transformers (default: vllm)
  --port=<port>                 Port to serve on (default: 8000)

Options for download:
  --cache-dir=<path>            Where to save model (default: ~/.cache/huggingface)

Examples:
  # Download model
  $(basename "$0") download unsloth/gemma-4-4b

  # Fine-tune with custom dataset
  $(basename "$0") finetune --model=unsloth/gemma-4-4b --dataset=/home/\$USER/data/train.jsonl --4bit

  # Start inference server
  $(basename "$0") serve /home/\$USER/gemma-output/final --backend=vllm

Notes:
  - Run 'install-unsloth' first to set up the environment
  - Activate conda: conda activate unsloth
  - Datasets should be JSONL with 'instruction' and 'output' fields

EOF
}

# Parse common options
parse_opts() {
    MODEL="unsloth/gemma-4-4b"
    DATASET=""
    OUTPUT="$DEFAULT_OUTPUT_DIR"
    EPOCHS=3
    BATCH_SIZE=2
    LEARNING_RATE="2e-4"
    MAX_SEQ_LENGTH=2048
    QUANTIZATION=""
    BACKEND="vllm"
    PORT=8000
    CACHE_DIR="$HOME/.cache/huggingface"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --model=*) MODEL="${1#*=}" ;;
            --dataset=*) DATASET="${1#*=}" ;;
            --output=*) OUTPUT="${1#*=}" ;;
            --epochs=*) EPOCHS="${1#*=}" ;;
            --batch-size=*) BATCH_SIZE="${1#*=}" ;;
            --learning-rate=*) LEARNING_RATE="${1#*=}" ;;
            --max-seq-length=*) MAX_SEQ_LENGTH="${1#*=}" ;;
            --4bit) QUANTIZATION="4bit" ;;
            --8bit) QUANTIZATION="8bit" ;;
            --backend=*) BACKEND="${1#*=}" ;;
            --port=*) PORT="${1#*=}" ;;
            --cache-dir=*) CACHE_DIR="${1#*=}" ;;
            --) shift; break ;;
            --*) echo "Unknown option: $1"; exit 1 ;;
            *) break ;;
        esac
        shift
    done
}

cmd_download() {
    local model="${1:-$MODEL}"
    
    echo -e "${BLUE}Downloading Gemma model: $model${NC}"
    echo "Cache directory: $CACHE_DIR"
    echo ""
    
    # Check if unsloth is available
    if ! python -c "import unsloth" 2>/dev/null; then
        echo -e "${YELLOW}Unsloth not found in current Python environment${NC}"
        echo "Please run: conda activate unsloth"
        exit 1
    fi
    
    python << EOF
from unsloth import FastLanguageModel
import torch

print(f"Downloading {model}...")

model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="$model",
    max_seq_length=$MAX_SEQ_LENGTH,
    dtype=torch.bfloat16,
    load_in_4bit=True,
)

print(f"✓ Model downloaded successfully")
print(f"  Location: $CACHE_DIR")
EOF

    echo ""
    echo -e "${GREEN}✓ Model downloaded to $CACHE_DIR${NC}"
}

cmd_finetune() {
    echo -e "${BLUE}Starting fine-tuning with Unsloth${NC}"
    echo ""
    
    # Validate inputs
    [[ -z "$DATASET" ]] && { echo -e "${RED}Error: --dataset required${NC}"; exit 1; }
    [[ ! -f "$DATASET" ]] && { echo -e "${RED}Error: Dataset not found: $DATASET${NC}"; exit 1; }
    
    # Check if unsloth is available
    if ! python -c "import unsloth" 2>/dev/null; then
        echo -e "${YELLOW}Unsloth not found in current Python environment${NC}"
        echo "Please run: conda activate unsloth"
        exit 1
    fi
    
    # Estimate VRAM
    echo "Configuration:"
    echo "  Model: $MODEL"
    echo "  Dataset: $DATASET"
    echo "  Output: $OUTPUT"
    echo "  Epochs: $EPOCHS"
    echo "  Batch size: $BATCH_SIZE"
    echo "  Learning rate: $LEARNING_RATE"
    echo "  Max sequence length: $MAX_SEQ_LENGTH"
    [[ -n "$QUANTIZATION" ]] && echo "  Quantization: $QUANTIZATION"
    echo ""
    
    # Check GPU memory
    echo "GPU Status:"
    nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv,noheader
    echo ""
    
    mkdir -p "$OUTPUT"
    
    # Create training script
    local train_script="$OUTPUT/train.py"
    
    cat > "$train_script" << 'PYTHON_EOF'
import torch
from unsloth import FastLanguageModel
from datasets import load_dataset
from trl import SFTTrainer
from transformers import TrainingArguments
import json

# Configuration
MODEL_NAME = "{{MODEL}}"
DATASET_PATH = "{{DATASET}}"
OUTPUT_DIR = "{{OUTPUT}}"
EPOCHS = {{EPOCHS}}
BATCH_SIZE = {{BATCH_SIZE}}
LEARNING_RATE = {{LEARNING_RATE}}
MAX_SEQ_LENGTH = {{MAX_SEQ_LENGTH}}
LOAD_IN_4BIT = {{LOAD_IN_4BIT}}

print(f"Loading model: {MODEL_NAME}")

model, tokenizer = FastLanguageModel.from_pretrained(
    model_name=MODEL_NAME,
    max_seq_length=MAX_SEQ_LENGTH,
    dtype=torch.bfloat16,
    load_in_4bit=LOAD_IN_4BIT,
)

model = FastLanguageModel.get_peft_model(
    model,
    r=16,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj", 
                   "gate_proj", "up_proj", "down_proj"],
    lora_alpha=16,
    lora_dropout=0,
    bias="none",
    use_gradient_checkpointing="unsloth",
    random_state=3407,
)

print("Loading dataset...")

# Load JSONL dataset
dataset = load_dataset("json", data_files=DATASET_PATH, split="train")

def formatting_prompts_func(examples):
    texts = []
    for instruction, output in zip(examples["instruction"], examples["output"]):
        text = f"### Instruction:\n{instruction}\n\n### Response:\n{output}"
        texts.append(text)
    return { "text": texts }

dataset = dataset.map(formatting_prompts_func, batched=True)

print(f"Dataset loaded: {len(dataset)} examples")
print(f"Starting training for {EPOCHS} epochs...")

trainer = SFTTrainer(
    model=model,
    tokenizer=tokenizer,
    train_dataset=dataset,
    dataset_text_field="text",
    max_seq_length=MAX_SEQ_LENGTH,
    dataset_num_proc=2,
    args=TrainingArguments(
        per_device_train_batch_size=BATCH_SIZE,
        gradient_accumulation_steps=4,
        num_train_epochs=EPOCHS,
        learning_rate=LEARNING_RATE,
        fp16=not torch.cuda.is_bf16_supported(),
        bf16=torch.cuda.is_bf16_supported(),
        logging_steps=10,
        optim="adamw_8bit",
        weight_decay=0.01,
        lr_scheduler_type="linear",
        seed=3407,
        output_dir=OUTPUT_DIR,
        save_strategy="epoch",
    ),
)

trainer.train()

print("Saving model...")
model.save_pretrained(f"{OUTPUT_DIR}/final")
tokenizer.save_pretrained(f"{OUTPUT_DIR}/final")

print(f"✓ Training complete! Model saved to {OUTPUT_DIR}/final")
PYTHON_EOF

    # Replace placeholders
    sed -i "s|{{MODEL}}|$MODEL|g" "$train_script"
    sed -i "s|{{DATASET}}|$DATASET|g" "$train_script"
    sed -i "s|{{OUTPUT}}|$OUTPUT|g" "$train_script"
    sed -i "s|{{EPOCHS}}|$EPOCHS|g" "$train_script"
    sed -i "s|{{BATCH_SIZE}}|$BATCH_SIZE|g" "$train_script"
    sed -i "s|{{LEARNING_RATE}}|$LEARNING_RATE|g" "$train_script"
    sed -i "s|{{MAX_SEQ_LENGTH}}|$MAX_SEQ_LENGTH|g" "$train_script"
    
    if [[ "$QUANTIZATION" == "4bit" ]]; then
        sed -i "s|{{LOAD_IN_4BIT}}|True|g" "$train_script"
    else
        sed -i "s|{{LOAD_IN_4BIT}}|False|g" "$train_script"
    fi
    
    echo "Training script created: $train_script"
    echo ""
    
    # Run training
    python "$train_script"
    
    echo ""
    echo -e "${GREEN}✓ Fine-tuning complete!${NC}"
    echo "Model saved to: $OUTPUT/final"
    echo ""
    echo "To download to your local machine:"
    echo "  ./gcp_transfer.sh download <instance>:$OUTPUT/final ./my-model/"
}

cmd_serve() {
    local model_path="${1:-}"
    
    [[ -z "$model_path" ]] && { echo -e "${RED}Error: Model path required${NC}"; exit 1; }
    [[ ! -d "$model_path" ]] && { echo -e "${RED}Error: Model directory not found: $model_path${NC}"; exit 1; }
    
    echo -e "${BLUE}Starting inference server${NC}"
    echo "Model: $model_path"
    echo "Backend: $BACKEND"
    echo "Port: $PORT"
    echo ""
    
    case "$BACKEND" in
        vllm)
            if ! command -v python -m vllm.entrypoints.openai.api_server &>/dev/null; then
                echo "Installing vLLM..."
                pip install vllm
            fi
            
            echo "Starting vLLM server..."
            echo "API will be available at: http://localhost:$PORT"
            echo ""
            python -m vllm.entrypoints.openai.api_server \
                --model "$model_path" \
                --port $PORT \
                --host 0.0.0.0
            ;;
            
        transformers)
            echo "Starting transformers server..."
            python << EOF
from transformers import AutoModelForCausalLM, AutoTokenizer
from flask import Flask, request, jsonify
import torch

app = Flask(__name__)

print("Loading model...")
model = AutoModelForCausalLM.from_pretrained("$model_path", torch_dtype=torch.bfloat16, device_map="auto")
tokenizer = AutoTokenizer.from_pretrained("$model_path")

@app.route("/generate", methods=["POST"])
def generate():
    data = request.json
    prompt = data.get("prompt", "")
    max_tokens = data.get("max_tokens", 100)
    
    inputs = tokenizer(prompt, return_tensors="pt").to(model.device)
    outputs = model.generate(**inputs, max_new_tokens=max_tokens)
    response = tokenizer.decode(outputs[0], skip_special_tokens=True)
    
    return jsonify({"response": response})

@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})

if __name__ == "__main__":
    print(f"Server starting on port $PORT")
    app.run(host="0.0.0.0", port=$PORT)
EOF
            ;;
            
        ollama)
            if ! command -v ollama &>/dev/null; then
                echo -e "${RED}Ollama not installed. Run: ./gcp_setup.sh install-ollama${NC}"
                exit 1
            fi
            
            echo "Creating Ollama model..."
            local modelfile="$OUTPUT/Modelfile"
            cat > "$modelfile" << EOF
FROM $model_path
PARAMETER temperature 0.7
PARAMETER top_p 0.9
EOF
            
            ollama create gemma-finetuned -f "$modelfile"
            echo "Starting Ollama server..."
            ollama serve
            ;;
            
        *)
            echo -e "${RED}Unknown backend: $BACKEND${NC}"
            exit 1
            ;;
    esac
}

# Main
cmd="${1:-}"
shift || true

parse_opts "$@"

case "$cmd" in
    download)
        cmd_download "${1:-}"
        ;;
    finetune)
        cmd_finetune
        ;;
    serve)
        cmd_serve "${1:-}"
        ;;
    *)
        show_help
        exit 0
        ;;
esac
