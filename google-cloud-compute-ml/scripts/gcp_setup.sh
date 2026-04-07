#!/bin/bash
#
# gcp_setup.sh - Setup ML environment on GPU VMs
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_help() {
    cat << EOF
Usage: $(basename "$0") <command> [options]

Commands:
  cuda-check               Verify GPU and CUDA are working
  install-unsloth          Install Unsloth and dependencies for fine-tuning
  install-ollama           Install Ollama for inference
  install-jupyter          Install and configure JupyterLab
  install-docker           Install Docker and NVIDIA Container Toolkit

Options:
  --python-version=<ver>   Python version for conda env (default: 3.10)
  --cuda-version=<ver>     CUDA version to target (default: auto-detect)

Examples:
  $(basename "$0") cuda-check
  $(basename "$0") install-unsloth
  $(basename "$0") install-jupyter

Notes:
  - Run these commands INSIDE the VM (via SSH)
  - Deep Learning VM images have CUDA pre-installed
  - install-unsloth creates a conda environment named 'unsloth'

EOF
}

cmd_cuda_check() {
    echo -e "${BLUE}Checking GPU and CUDA status...${NC}"
    echo ""
    
    if ! command -v nvidia-smi &> /dev/null; then
        echo -e "${RED}✗ nvidia-smi not found${NC}"
        echo "CUDA drivers may not be installed."
        echo ""
        echo "For Deep Learning VMs, try:"
        echo "  sudo /opt/deeplearning/install-driver.sh"
        exit 1
    fi
    
    echo -e "${GREEN}✓ nvidia-smi found${NC}"
    echo ""
    
    echo "GPU Information:"
    echo "================"
    nvidia-smi --query-gpu=name,memory.total,memory.free,driver_version --format=csv,noheader
    
    echo ""
    echo "CUDA Version:"
    nvidia-smi | grep "CUDA Version"
    
    echo ""
    echo "Processes using GPU:"
    nvidia-smi pmon -s um -c 1 || true
}

cmd_install_unsloth() {
    local python_version="${1:-3.10}"
    
    echo -e "${BLUE}Installing Unsloth and dependencies...${NC}"
    echo "Python version: $python_version"
    echo ""
    
    # Check if conda is available
    if ! command -v conda &> /dev/null; then
        echo -e "${YELLOW}Conda not found. Installing Miniconda...${NC}"
        
        wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
        bash /tmp/miniconda.sh -b -p $HOME/miniconda
        rm /tmp/miniconda.sh
        
        export PATH="$HOME/miniconda/bin:$PATH"
        eval "$($HOME/miniconda/bin/conda shell.bash hook)"
        
        echo -e "${GREEN}✓ Miniconda installed${NC}"
    fi
    
    # Initialize conda for bash
    conda init bash 2>/dev/null || true
    
    # Create conda environment
    echo "Creating conda environment 'unsloth'..."
    conda create -n unsloth python=$python_version -y
    
    # Activate environment
    source $(conda info --base)/etc/profile.d/conda.sh
    conda activate unsloth
    
    echo -e "${GREEN}✓ Conda environment 'unsloth' created${NC}"
    echo ""
    
    # Install PyTorch with CUDA
    echo "Installing PyTorch with CUDA support..."
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
    
    # Install Unsloth
    echo "Installing Unsloth..."
    pip install unsloth
    
    # Install additional dependencies
    echo "Installing additional dependencies..."
    pip install transformers datasets accelerate bitsandbytes peft trl
    pip install scipy scikit-learn matplotlib tensorboard jupyter
    
    echo ""
    echo -e "${GREEN}✓ Unsloth installation complete!${NC}"
    echo ""
    echo "To use:"
    echo "  conda activate unsloth"
    echo "  python -c 'import unsloth; print(unsloth.__version__)'"
    echo ""
    echo "Test GPU access:"
    echo "  python -c 'import torch; print(torch.cuda.is_available())'"
}

cmd_install_ollama() {
    echo -e "${BLUE}Installing Ollama...${NC}"
    echo ""
    
    if command -v ollama &> /dev/null; then
        echo -e "${YELLOW}Ollama already installed${NC}"
        ollama --version
        return 0
    fi
    
    # Install Ollama
    curl -fsSL https://ollama.com/install.sh | sh
    
    echo ""
    echo -e "${GREEN}✓ Ollama installed${NC}"
    echo ""
    echo "Usage:"
    echo "  ollama serve              # Start the server"
    echo "  ollama pull gemma:4b      # Download Gemma 4B"
    echo "  ollama run gemma:4b       # Run interactively"
    echo ""
    echo "For Gemma 4 (when available):"
    echo "  ollama pull gemma4:4b"
}

cmd_install_jupyter() {
    echo -e "${BLUE}Installing JupyterLab...${NC}"
    echo ""
    
    # Check if in conda environment
    if [[ -z "${CONDA_DEFAULT_ENV:-}" ]]; then
        echo -e "${YELLOW}Not in conda environment.${NC}"
        echo "Activating 'unsloth' environment..."
        
        source $(conda info --base)/etc/profile.d/conda.sh 2>/dev/null || true
        conda activate unsloth 2>/dev/null || {
            echo -e "${RED}Could not activate 'unsloth' environment${NC}"
            echo "Run 'install-unsloth' first, or activate your environment"
            exit 1
        }
    fi
    
    pip install jupyterlab notebook ipywidgets
    
    # Generate config
    jupyter notebook --generate-config -y 2>/dev/null || true
    
    # Set password if not set
    if ! grep -q "c.NotebookApp.password" ~/.jupyter/jupyter_notebook_config.py 2>/dev/null; then
        echo "Setting up Jupyter password..."
        echo "You will be prompted to enter a password"
        jupyter notebook password
    fi
    
    echo ""
    echo -e "${GREEN}✓ JupyterLab installed${NC}"
    echo ""
    echo "To start JupyterLab:"
    echo "  jupyter lab --ip=0.0.0.0 --no-browser --allow-root"
    echo ""
    echo "Then set up port forwarding from your local machine:"
    echo "  ./gcp_ssh.sh tunnel <instance-name> --local-port=8888 --remote-port=8888"
    echo ""
    echo "Access at: http://localhost:8888"
}

cmd_install_docker() {
    echo -e "${BLUE}Installing Docker and NVIDIA Container Toolkit...${NC}"
    echo ""
    
    # Install Docker
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker..."
        curl -fsSL https://get.docker.com | sh
        sudo usermod -aG docker $USER
        echo -e "${GREEN}✓ Docker installed${NC}"
        echo -e "${YELLOW}Log out and back in for group changes to take effect${NC}"
    else
        echo -e "${GREEN}✓ Docker already installed${NC}"
    fi
    
    # Install NVIDIA Container Toolkit
    echo "Installing NVIDIA Container Toolkit..."
    
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add - 2>/dev/null || true
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
    
    sudo apt-get update
    sudo apt-get install -y nvidia-docker2
    sudo systemctl restart docker
    
    echo ""
    echo -e "${GREEN}✓ NVIDIA Container Toolkit installed${NC}"
    echo ""
    echo "Test GPU in container:"
    echo "  docker run --gpus all nvidia/cuda:12.0-base nvidia-smi"
}

# Main
cmd="${1:-}"

# Parse options
PYTHON_VERSION="3.10"
CUDA_VERSION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --python-version=*) PYTHON_VERSION="${1#*=}" ;;
        --cuda-version=*) CUDA_VERSION="${1#*=}" ;;
        --) shift; break ;;
        --*) echo "Unknown option: $1"; exit 1 ;;
        *) break ;;
    esac
    shift
done

case "$cmd" in
    cuda-check)
        cmd_cuda_check
        ;;
    install-unsloth)
        cmd_install_unsloth "$PYTHON_VERSION"
        ;;
    install-ollama)
        cmd_install_ollama
        ;;
    install-jupyter)
        cmd_install_jupyter
        ;;
    install-docker)
        cmd_install_docker
        ;;
    *)
        show_help
        exit 0
        ;;
esac
