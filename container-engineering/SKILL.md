---
name: container-engineering
description: Build, test, and push optimized GPU Docker containers for ML training on Google Cloud. Use when the user asks to build a container, write a Dockerfile, set up CUDA, push to Artifact Registry, use uv in Docker, run Cloud Build, or validate a container locally before deployment.
---

<container-engineering>
This skill covers building production-ready GPU containers for ML training workloads and pushing them to Google Cloud Artifact Registry.

**What's covered:**
- `<Dockerfile-patterns>` — Multi-stage build with `uv` (recommended) and pip alternatives
- `<cuda-compatibility>` — Matching CUDA version to host driver and GPU architecture
- `<build-and-push>` — Using `build-and-push.sh` to build with layer caching and push
- `<local-testing>` — Validating containers locally with `test-container-locally.sh`
- `<cloud-build>` — CI/CD builds via Cloud Build using `cloudbuild.yaml`
- `<cost-and-storage>` — Keeping Artifact Registry lean and builds fast
- `<anti-patterns>` — Common mistakes that bloat images or break GPU access

**Scripts:** `scripts/build-and-push.sh`, `scripts/test-container-locally.sh`, `scripts/validate-cuda.sh`
**References:** `references/cuda-compatibility-matrix.md`, `references/cheatsheet.md`
**Dockerfile templates:** `scripts/Dockerfile.template.uv` (recommended), `scripts/Dockerfile.template.pip`, `scripts/Dockerfile.template.vertex`

**Prerequisite:** `google-cloud-account` skill (Artifact Registry repository must exist).
</container-engineering>

<Dockerfile-patterns>
## Recommended: Multi-Stage Build with uv

Use `scripts/Dockerfile.template.uv` as your starting point. It produces ~1.5GB images vs ~8GB from single-stage builds.

Key structure:
- **Stage 1 (builder):** `nvidia/cuda:12.4.1-devel-ubuntu22.04` — installs uv, Python, all packages
- **Stage 2 (runtime):** `nvidia/cuda:12.4.1-runtime-ubuntu22.04` — copies only the venv, no build tools

Critical uv env vars in builder stage:
```dockerfile
COPY --from=ghcr.io/astral-sh/uv:0.5 /uv /bin/uv
ENV UV_COMPILE_BYTECODE=1 \   # faster container startup
    UV_LINK_MODE=copy \        # required for multi-stage COPY to work
    UV_PYTHON_INSTALL_DIR=/opt/python \
    UV_PYTHON_PREFERENCE=only-managed
```

Install PyTorch (adjust `--index-url` for your CUDA version):
```dockerfile
RUN uv pip install --no-cache-dir \
    --python /opt/venv/bin/python \
    torch==2.5.1 torchvision==0.20.1 \
    --index-url https://download.pytorch.org/whl/cu124
```

Copy the venv into the runtime stage and set `PATH`:
```dockerfile
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH" PYTHONUNBUFFERED=1
```

**Layer caching order** (least → most frequently changed):
1. `apt-get` system deps
2. PyTorch + heavy ML frameworks
3. `COPY requirements.txt` + `uv pip install -r`
4. `COPY src/` last

**Security:** Always add a non-root user in runtime stage:
```dockerfile
RUN groupadd -r trainer && useradd -r -g trainer trainer
COPY --chown=trainer:trainer . /workspace
USER trainer
```

See `scripts/Dockerfile.template.vertex` for Vertex AI–specific patterns (uses `AIP_MODEL_DIR`, `AIP_TENSORBOARD_LOG_DIR` env vars).
</Dockerfile-patterns>

<cuda-compatibility>
Container CUDA must be ≤ host driver max CUDA (shown in `nvidia-smi` top-right corner).

| CUDA Toolkit | Min Driver | Use For |
|---|---|---|
| 12.4 | 525.60.13 | Vertex AI, modern GPUs (Ampere, Ada, Hopper) |
| 12.6 | 525.60.13 | RunPod, latest hardware |
| 11.8 | 450.80.02 | Maximum compatibility, older hosts |

**Check host before picking a version:**
```bash
nvidia-smi                                          # shows "CUDA Version: X.Y" — container must be ≤ this
nvidia-smi --query-gpu=compute_cap --format=csv    # shows GPU architecture
./scripts/validate-cuda.sh 12.4                    # validates automatically
```

Full tables (GPU architecture → min CUDA, PyTorch index URLs) are in `references/cuda-compatibility-matrix.md`.

**Vertex AI constraint:** Max CUDA 12.4. Use `nvidia/cuda:12.4.1-devel-ubuntu22.04` for builder and `nvidia/cuda:12.4.1-runtime-ubuntu22.04` for runtime.
</cuda-compatibility>

<build-and-push>
Use `scripts/build-and-push.sh`. Run without arguments or with `--help` to see usage.

```bash
# Minimal
PROJECT_ID=my-project ./scripts/build-and-push.sh v1.0.0

# With overrides
PROJECT_ID=my-project REGION=us-central1 REPO_NAME=ml-containers IMAGE_NAME=training-gpu \
  ./scripts/build-and-push.sh v1.0.0
```

The script:
1. Authenticates Docker to Artifact Registry (`gcloud auth configure-docker`)
2. Pulls the `:cache` tag to warm layer cache
3. Builds with `--platform linux/amd64 --build-arg BUILDKIT_INLINE_CACHE=1`
4. Tags both `:version` and `:cache`, pushes both
5. Prints the full Artifact Registry URI for use in Vertex AI jobs

**Artifact Registry URI format:** `{REGION}-docker.pkg.dev/{PROJECT_ID}/{REPO_NAME}/{IMAGE_NAME}:{TAG}`

The repository must already exist. Create it with:
```bash
gcloud artifacts repositories create ml-containers \
  --repository-format=docker --location=us-central1
```
</build-and-push>

<local-testing>
Always test locally before pushing to cloud. Use `scripts/test-container-locally.sh`.

```bash
# By tag (constructs full path from PROJECT_ID env)
PROJECT_ID=my-project ./scripts/test-container-locally.sh training-gpu:v1.0.0

# By full path
./scripts/test-container-locally.sh us-central1-docker.pkg.dev/my-project/ml-containers/training-gpu:v1.0.0
```

Tests run by the script:
- Container starts
- NVIDIA runtime available (`--gpus all`)
- PyTorch CUDA available + correct version
- GPU tensor operations (matmul)
- GPU memory allocation (~400MB)
- Optional: `transformers`, `accelerate` imports

Use `scripts/validate-cuda.sh 12.4` separately to check host/container CUDA compatibility before building.

**Requires NVIDIA Container Toolkit** on host. Install guide: `references/cheatsheet.md` → "NVIDIA Container Toolkit".
</local-testing>

<cloud-build>
Use `scripts/cloudbuild.yaml` for CI/CD. Submit with:

```bash
gcloud builds submit --config scripts/cloudbuild.yaml
# With overrides:
gcloud builds submit --config scripts/cloudbuild.yaml \
  --substitutions=_REGION=us-central1,_IMAGE=training-gpu
```

Cloud Build handles auth to Artifact Registry automatically. It uses `N1_HIGHCPU_32` machines with 100GB disk — suitable for CUDA builds. Layer caching via `:cache` tag is pre-wired.

**Cost tip:** Cloud Build charges per build-minute on high-CPU machines. Layer caching (already configured) dramatically cuts re-build time. Use Cloud Build only for production pushes; build locally for iteration.
</cloud-build>

<cost-and-storage>
ML container images are large (5–15GB uncompressed). Storage in Artifact Registry costs ~$0.10/GB/month.

**Keep storage lean:**
- Only push tagged releases + the `:cache` tag — don't let untagged digests accumulate
- Set a lifecycle policy to delete old images automatically:
```bash
gcloud artifacts repositories set-cleanup-policies ml-containers \
  --location=us-central1 \
  --policy='[{"name":"delete-old","condition":{"tagState":"ANY","olderThan":"30d"},"action":{"type":"Delete"}}]'
```
- Host your registry in the **same region** as your training workloads (Vertex AI, Compute Engine) — cross-region egress is charged; same-region is free.

**Keep builds fast:**
- Use uv (10–100× faster than pip for large dependency sets)
- Always build with `DOCKER_BUILDKIT=1` and `--build-arg BUILDKIT_INLINE_CACHE=1`
- Structure Dockerfile layers correctly (stable deps first, code last)
</cost-and-storage>

<anti-patterns>
- **Copying code before deps** — invalidates all package layers on every commit. `COPY src/` must be last.
- **Single-stage build from `-devel` image** — ships 8GB+ with nvcc, headers, compiler. Use multi-stage.
- **Missing `.dockerignore`** — `.git`, `__pycache__`, `*.pyc`, notebooks all bloat the build context. Use `scripts/.dockerignore.example`.
- **Root user in production** — Vertex AI requires non-root. Always add a `USER trainer` in the runtime stage.
- **Container CUDA > host driver max** — causes `Failed to initialize NVML`. Check with `validate-cuda.sh` first.
- **Wrong CUDA architecture** — `no kernel image` error. RTX 4090 / H100 need CUDA 11.8+. Check compute capability with `nvidia-smi --query-gpu=compute_cap`.
- **Missing NVIDIA runtime** — `could not select device driver`. Install `nvidia-container-toolkit` on host and restart Docker.
</anti-patterns>

<container-engineering-scripts>
| Script | Run without args | Purpose |
|---|---|---|
| `build-and-push.sh` | shows usage | Build with layer caching and push to Artifact Registry |
| `test-container-locally.sh` | shows usage | Validate GPU/CUDA/PyTorch inside the container |
| `validate-cuda.sh 12.4` | shows usage | Check host can run a given CUDA version |
</container-engineering-scripts>

<container-engineering-reference>
| File | Contents |
|---|---|
| `references/cuda-compatibility-matrix.md` | Full CUDA ↔ driver ↔ GPU architecture ↔ PyTorch version tables, cloud platform limits |
| `references/cheatsheet.md` | Quick commands: docker build/run/clean, Artifact Registry push/pull, Cloud Build, uv, Vertex AI job submission |
| `scripts/Dockerfile.template.uv` | Full annotated multi-stage Dockerfile using uv (recommended) |
| `scripts/Dockerfile.template.pip` | pip-based alternative |
| `scripts/Dockerfile.template.vertex` | Vertex AI–optimized variant |
</container-engineering-reference>

<examples>
**Scenario:** Build and validate a CUDA 12.4 training container, then push for use in a Vertex AI job.

**Step 1 — Choose template and customize:**
```bash
cp scripts/Dockerfile.template.uv Dockerfile
# Edit: set your Python version, adjust torch version and --index-url to match CUDA
```

**Step 2 — Validate host CUDA:**
```bash
./scripts/validate-cuda.sh 12.4
# Expected: "✓ Compatible: Container CUDA 12.4 ≤ Host max 12.x"
# If incompatible: switch to a lower CUDA base image
```

**Step 3 — Build and test locally:**
```bash
DOCKER_BUILDKIT=1 docker build -t training-gpu:v1.0.0 .
PROJECT_ID=my-project ./scripts/test-container-locally.sh training-gpu:v1.0.0
# Watch for: ✓ CUDA available to PyTorch, ✓ GPU tensor operations
```

**Step 4 — Push to Artifact Registry:**
```bash
PROJECT_ID=my-project REGION=us-central1 ./scripts/build-and-push.sh v1.0.0
# Outputs: us-central1-docker.pkg.dev/my-project/ml-containers/training-gpu:v1.0.0
```

**Step 5 — Use in Vertex AI:**
```bash
gcloud ai custom-jobs create \
  --region=us-central1 \
  --display-name=my-training-job \
  --worker-pool-spec=machine-type=n1-standard-8,accelerator-type=NVIDIA_TESLA_T4,accelerator-count=1,\
container-image-uri=us-central1-docker.pkg.dev/my-project/ml-containers/training-gpu:v1.0.0
```

**Common mistake — GPU not detected after local build:**
```bash
docker run --rm myimage:latest python -c "import torch; print(torch.cuda.is_available())"
# Returns False — forgot --gpus all flag

docker run --rm --gpus all myimage:latest python -c "import torch; print(torch.cuda.is_available())"
# Returns True
```
</examples>