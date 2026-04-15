# =============================================================================
# Dockerfile - Gemma 4 E2B Fine-Tuning (Vertex AI + Local)
# =============================================================================
# Multi-stage build using uv for fast installs.
# Builder: CUDA 12.4 devel + compile all Python deps
# Runtime: CUDA 12.4 runtime only, non-root user, Vertex AI ready
#
# Build:
#   DOCKER_BUILDKIT=1 docker build -t gemma4-train:v1.0.0 .
#
# Test locally (requires NVIDIA Container Toolkit):
#   docker run --rm --gpus all gemma4-train:v1.0.0 python -c "import torch; print(torch.cuda.is_available())"
#
# Push to Artifact Registry:
#   PROJECT_ID=my-project REGION=us-central1 \
#     ~/container-engineering/scripts/build-and-push.sh v1.0.0
# =============================================================================

# ---------------------------------------------------------------------------
# STAGE 1: Builder — compile Python packages into /opt/venv
# ---------------------------------------------------------------------------
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04 AS builder

COPY --from=ghcr.io/astral-sh/uv:0.5 /uv /bin/uv

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_INSTALL_DIR=/opt/python \
    UV_PYTHON_PREFERENCE=only-managed \
    UV_NO_PROGRESS=1

RUN uv python install 3.11
RUN uv venv /opt/venv --python 3.11

# --- PyTorch with CUDA 12.4 ---
RUN uv pip install --no-cache-dir \
    --python /opt/venv/bin/python \
    torch==2.5.1 \
    torchvision==0.20.1 \
    --index-url https://download.pytorch.org/whl/cu124

# --- Training stack (stable deps first for layer caching) ---
COPY pyproject.toml /tmp/pyproject.toml
RUN uv pip install --no-cache-dir \
    --python /opt/venv/bin/python \
    trl peft transformers datasets accelerate bitsandbytes \
    pyyaml huggingface-hub google-cloud-storage \
    --index-url https://download.pytorch.org/whl/cu124 \
    --extra-index-url https://pypi.org/simple

# ---------------------------------------------------------------------------
# STAGE 2: Runtime — minimal image, no compilers
# ---------------------------------------------------------------------------
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04 AS runtime

# Security: non-root user (Vertex AI requirement)
RUN groupadd -r trainer -g 1000 && \
    useradd -r -g trainer -u 1000 -m trainer && \
    mkdir -p /workspace /gcs && \
    chown -R trainer:trainer /workspace /gcs

COPY --from=builder /opt/venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONFAULTHANDLER=1

# Minimal runtime system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /workspace

# Copy training code LAST to maximize layer caching
COPY --chown=trainer:trainer configs/ /workspace/configs/
COPY --chown=trainer:trainer data/ /workspace/data/
COPY --chown=trainer:trainer train_hf_peft.py /workspace/train.py
COPY --chown=trainer:trainer inference.py /workspace/
COPY --chown=trainer:trainer export.py /workspace/

USER trainer

# Vertex AI sets AIP_MODEL_DIR, AIP_CHECKPOINT_DIR, AIP_TENSORBOARD_LOG_DIR
# at runtime. The training script reads these for output paths.
ENTRYPOINT ["python", "train.py"]
CMD ["--config=configs/hf_qlora.yaml", "--dataset_path=data/formatted_dataset"]
