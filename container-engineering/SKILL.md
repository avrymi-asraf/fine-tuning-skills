---
name: container-engineering
description: Build, test, and push optimized GPU Docker containers for ML training on Google Cloud. Use when the user asks to create a Dockerfile, set up CUDA in a container, push images to Artifact Registry, validate GPU access locally, run Cloud Build for ML containers, or troubleshoot container-related GPU errors.
---

<container-engineering>
This skill covers building production-ready GPU containers for ML training and pushing them to Google Cloud Artifact Registry. A GPU container must match the host CUDA version, use multi-stage builds to stay small, and pass GPU validation before deployment.

**What's covered:**
- `<dockerfile-patterns>` — Multi-stage builds with uv (recommended) and pip; layer caching strategy
- `<cuda-compatibility>` — Matching container CUDA to host driver and GPU architecture
- `<build-and-push>` — Building with layer caching and pushing to Artifact Registry via `build-and-push.sh`
- `<local-testing>` — Validating GPU, CUDA, and PyTorch inside the container before deployment
- `<cloud-build>` — CI/CD builds with `cloudbuild.yaml` and Cloud Build
- `<cost-and-storage>` — Keeping Artifact Registry lean and builds fast
- `<anti-patterns>` — Mistakes that bloat images or break GPU access

**Scripts:** `scripts/build-and-push.sh`, `scripts/test-container-locally.sh`, `scripts/validate-cuda.sh`
**References:** `references/cuda-compatibility-matrix.md`, `references/cheatsheet.md`
**Templates:** `scripts/Dockerfile.template.uv` (recommended), `scripts/Dockerfile.template.pip`, `scripts/Dockerfile.template.vertex`

**Prerequisite:** `cloud-infrastructure-setup` skill (Artifact Registry repository must exist).
</container-engineering>

<dockerfile-patterns>
Start from `scripts/Dockerfile.template.uv`. It produces ~1.5 GB images vs ~8 GB from single-stage `-devel` builds.

**Two stages:**
- **Builder** (`nvidia/cuda:12.4.1-devel-ubuntu22.04`) — installs uv, Python, all packages into `/opt/venv`
- **Runtime** (`nvidia/cuda:12.4.1-runtime-ubuntu22.04`) — copies only the venv, no compilers

Critical uv config in the builder:
```dockerfile
COPY --from=ghcr.io/astral-sh/uv:0.5 /uv /bin/uv
ENV UV_COMPILE_BYTECODE=1 \   # faster startup
    UV_LINK_MODE=copy \        # required for multi-stage COPY
    UV_PYTHON_INSTALL_DIR=/opt/python \
    UV_PYTHON_PREFERENCE=only-managed
```

Install PyTorch with the correct CUDA index:
```dockerfile
RUN uv pip install --no-cache-dir \
    --python /opt/venv/bin/python \
    torch==2.5.1 torchvision==0.20.1 \
    --index-url https://download.pytorch.org/whl/cu124
```

Runtime stage — copy venv and add non-root user:
```dockerfile
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH" PYTHONUNBUFFERED=1
RUN groupadd -r trainer && useradd -r -g trainer trainer
COPY --chown=trainer:trainer . /workspace
USER trainer
```

**Layer order** (stable → volatile): apt deps → PyTorch → `COPY requirements.txt` + install → `COPY src/` last.

Use `scripts/Dockerfile.template.vertex` for Vertex AI jobs — it handles `AIP_MODEL_DIR`, `AIP_TENSORBOARD_LOG_DIR`, and uses `ENTRYPOINT ["python", "train.py"]`.
Use `scripts/Dockerfile.template.pip` if uv is not an option.
</dockerfile-patterns>

<cuda-compatibility>
**Rule:** Container CUDA must be ≤ host driver max CUDA (shown in `nvidia-smi` top-right corner).

| CUDA Toolkit | Min Driver | Use For |
|---|---|---|
| 12.4 | 525.60.13 | Vertex AI, modern GPUs (Ampere, Ada, Hopper) |
| 12.6 | 525.60.13 | RunPod, latest hardware |
| 11.8 | 450.80.02 | Maximum compatibility, older hosts |

Check host before choosing a version:
```bash
nvidia-smi                                        # "CUDA Version: X.Y" — container must be ≤ this
nvidia-smi --query-gpu=compute_cap --format=csv   # GPU architecture
./scripts/validate-cuda.sh 12.4                   # automated check
```

**Vertex AI constraint:** Max CUDA 12.4. Use `nvidia/cuda:12.4.1-devel-ubuntu22.04` for builder, `nvidia/cuda:12.4.1-runtime-ubuntu22.04` for runtime.

Full tables (GPU architecture → min CUDA, PyTorch index URLs, cloud platform limits) are in `references/cuda-compatibility-matrix.md`.
</cuda-compatibility>

<build-and-push>
Use `scripts/build-and-push.sh`. Run with `--help` for all options.

```bash
# Minimal
PROJECT_ID=my-project ./scripts/build-and-push.sh v1.0.0

# With overrides
PROJECT_ID=my-project REGION=us-central1 REPO_NAME=ml-containers IMAGE_NAME=training-gpu \
  ./scripts/build-and-push.sh v1.0.0
```

What the script does:
1. Authenticates Docker to Artifact Registry (`gcloud auth configure-docker`)
2. Pulls `:cache` tag to warm layer cache
3. Builds with `--platform linux/amd64 --build-arg BUILDKIT_INLINE_CACHE=1`
4. Tags `:version` and `:cache`, pushes both
5. Prints the full Artifact Registry URI

**Image URI format:** `{REGION}-docker.pkg.dev/{PROJECT_ID}/{REPO_NAME}/{IMAGE_NAME}:{TAG}`

The repository must already exist:
```bash
gcloud artifacts repositories create ml-containers \
  --repository-format=docker --location=us-central1
```
</build-and-push>

<local-testing>
Always test locally before pushing. Use `scripts/test-container-locally.sh`.

```bash
# By tag (uses PROJECT_ID env to construct path)
PROJECT_ID=my-project ./scripts/test-container-locally.sh training-gpu:v1.0.0

# By full path
./scripts/test-container-locally.sh us-central1-docker.pkg.dev/my-project/ml-containers/training-gpu:v1.0.0
```

The script validates: container starts → NVIDIA runtime (`--gpus all`) → PyTorch CUDA available → GPU tensor ops → GPU memory allocation → optional `transformers`/`accelerate` imports.

Use `scripts/validate-cuda.sh 12.4` separately to check host/container CUDA compatibility before building.

**Requires NVIDIA Container Toolkit** on host. Install commands in `references/cheatsheet.md` → "NVIDIA Container Toolkit".
</local-testing>

<cloud-build>
Use `scripts/cloudbuild.yaml` for CI/CD:

```bash
gcloud builds submit --config scripts/cloudbuild.yaml
# With overrides:
gcloud builds submit --config scripts/cloudbuild.yaml \
  --substitutions=_REGION=us-central1,_IMAGE=training-gpu
```

Cloud Build authenticates to Artifact Registry automatically. Uses `N1_HIGHCPU_32` machines with 100 GB disk. Layer caching via `:cache` tag is pre-configured.

**Cost:** Cloud Build charges per build-minute on high-CPU machines. Use it for production pushes only; build locally for iteration.
</cloud-build>

<cost-and-storage>
ML images are large (5–15 GB uncompressed). Artifact Registry storage costs ~$0.10/GB/month.

**Keep storage lean:**
- Push only tagged releases + `:cache` — don't let untagged digests accumulate
- Set a cleanup policy:
  ```bash
  gcloud artifacts repositories set-cleanup-policies ml-containers \
    --location=us-central1 \
    --policy='[{"name":"delete-old","condition":{"tagState":"ANY","olderThan":"30d"},"action":{"type":"Delete"}}]'
  ```
- Host your registry in the **same region** as training workloads — cross-region egress is charged

**Keep builds fast:**
- Use uv (10–100× faster than pip for large dependency sets)
- Always build with `DOCKER_BUILDKIT=1`
- Structure layers correctly (stable deps first, code last)
</cost-and-storage>

<anti-patterns>
- **Copying code before deps** — invalidates all package layers on every commit. `COPY src/` must be last.
- **Single-stage `-devel` build** — ships 8 GB+ with nvcc, headers, compiler. Use multi-stage.
- **Missing `.dockerignore`** — `.git`, `__pycache__`, `*.pyc`, notebooks bloat the context. Use `scripts/.dockerignore.example`.
- **Root user in production** — Vertex AI requires non-root. Always add `USER trainer`.
- **Container CUDA > host driver max** — causes `Failed to initialize NVML`. Check with `validate-cuda.sh` first.
- **Wrong CUDA architecture** — `no kernel image` error. Check compute capability with `nvidia-smi --query-gpu=compute_cap`.
- **Missing NVIDIA runtime** — `could not select device driver`. Install `nvidia-container-toolkit` and restart Docker.
- **Forgetting `--gpus all`** — PyTorch reports `cuda.is_available() == False` without it.
</anti-patterns>

<container-engineering-scripts>
| Script | Run without args | Purpose |
|---|---|---|
| `build-and-push.sh` | shows usage | Build with layer caching and push to Artifact Registry |
| `test-container-locally.sh` | shows usage | Validate GPU/CUDA/PyTorch inside the container |
| `validate-cuda.sh` | shows usage | Check host can run a given CUDA version |
| `cloudbuild.yaml` | — (config) | Cloud Build definition for CI/CD builds |
</container-engineering-scripts>

<container-engineering-reference>
| File | Contents |
|---|---|
| `references/cuda-compatibility-matrix.md` | Full CUDA ↔ driver ↔ GPU architecture ↔ PyTorch version tables, cloud platform limits |
| `references/cheatsheet.md` | Quick commands: docker build/run/clean, Artifact Registry, Cloud Build, uv, Vertex AI submission, NVIDIA Toolkit install |
| `scripts/Dockerfile.template.uv` | Full annotated multi-stage Dockerfile using uv (recommended) |
| `scripts/Dockerfile.template.pip` | pip-based alternative |
| `scripts/Dockerfile.template.vertex` | Vertex AI–optimized variant with AIP env vars and ENTRYPOINT |
</container-engineering-reference>

<examples>
**Scenario:** Build and validate a CUDA 12.4 training container, then push for Vertex AI.

**Step 1 — Pick template and customize:**
```bash
cp scripts/Dockerfile.template.uv Dockerfile
# Set Python version, adjust torch version and --index-url to match CUDA
```

**Step 2 — Validate host CUDA:**
```bash
./scripts/validate-cuda.sh 12.4
# ✓ Compatible: Container CUDA 12.4 ≤ Host max 12.x
# If incompatible → use a lower CUDA base image
```

**Step 3 — Build and test locally:**
```bash
DOCKER_BUILDKIT=1 docker build -t training-gpu:v1.0.0 .
PROJECT_ID=my-project ./scripts/test-container-locally.sh training-gpu:v1.0.0
# ✓ CUDA available, ✓ GPU tensor ops, ✓ memory allocation
```

**Step 4 — Push to Artifact Registry:**
```bash
PROJECT_ID=my-project REGION=us-central1 ./scripts/build-and-push.sh v1.0.0
# → us-central1-docker.pkg.dev/my-project/ml-containers/training-gpu:v1.0.0
```

**Step 5 — Submit Vertex AI job:**
```bash
gcloud ai custom-jobs create \
  --region=us-central1 \
  --display-name=my-training-job \
  --worker-pool-spec=machine-type=n1-standard-8,accelerator-type=NVIDIA_TESLA_T4,\
accelerator-count=1,container-image-uri=us-central1-docker.pkg.dev/my-project/ml-containers/training-gpu:v1.0.0
```

**Common mistake — GPU not detected locally:**
```bash
docker run --rm myimage python -c "import torch; print(torch.cuda.is_available())"
# False — forgot --gpus all

docker run --rm --gpus all myimage python -c "import torch; print(torch.cuda.is_available())"
# True
```
</examples>

<checklist>

### Container build
- [ ] Multi-stage build — `-devel` for builder, `-runtime` for final
- [ ] Container CUDA ≤ host driver max (verified with `validate-cuda.sh`)
- [ ] Layer order: apt → PyTorch → requirements → code
- [ ] `.dockerignore` excludes `.git`, `__pycache__`, notebooks
- [ ] Non-root `USER trainer` in runtime stage

### Testing
- [ ] `test-container-locally.sh` passes all checks (CUDA, PyTorch, GPU ops)
- [ ] `--gpus all` used when running containers with GPU access

### Push and deploy
- [ ] Artifact Registry repository exists in the correct region
- [ ] `build-and-push.sh` builds and pushes with layer caching
- [ ] Image URI matches the format expected by Vertex AI / deployment target

### Storage
- [ ] Cleanup policy set on Artifact Registry to delete old images
- [ ] Registry co-located with training workloads (same region)
</checklist>