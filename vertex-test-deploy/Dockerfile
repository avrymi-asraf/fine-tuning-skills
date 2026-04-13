FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

# System Setup
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 \
    python3-pip \
    python3.11-venv \
    && rm -rf /var/lib/apt/lists/*

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Create virtual environment
RUN python3.11 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install minimal dependencies for testing
RUN pip install --upgrade pip
RUN pip install torch --index-url https://download.pytorch.org/whl/cu124

# Security: Non-root user (Vertex AI requirement)
RUN groupadd -r trainer -g 1000 && \
    useradd -r -g trainer -u 1000 trainer && \
    mkdir -p /workspace && \
    chown -R trainer:trainer /workspace

WORKDIR /workspace

# Copy Training Code
COPY --chown=trainer:trainer train.py /workspace/

USER trainer

ENTRYPOINT ["python", "train.py"]

