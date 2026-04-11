# CUDA Compatibility Matrix

Quick reference for CUDA toolkit, driver, and GPU architecture compatibility.

---

## CUDA Toolkit ↔ Driver Version

| CUDA Toolkit | Minimum Driver | Release Date |
|-------------|----------------|--------------|
| 12.8 | 525.60.13 | Mar 2025 |
| 12.6 | 525.60.13 | Aug 2024 |
| 12.4 | 525.60.13 | Mar 2024 |
| 12.3 | 525.60.13 | Nov 2023 |
| 12.2 | 525.60.13 | June 2023 |
| 12.1 | 525.60.13 | Feb 2023 |
| 12.0 | 525.60.13 | Dec 2022 |
| 11.8 | 450.80.02 | Oct 2022 |
| 11.7 | 450.80.02 | May 2022 |
| 11.6 | 450.80.02 | Jan 2022 |
| 11.5 | 450.80.02 | Oct 2021 |
| 11.4 | 450.80.02 | June 2021 |
| 11.3 | 450.36.06 | Apr 2021 |
| 11.2 | 450.36.06 | Dec 2020 |
| 11.1 | 450.36.06 | Oct 2020 |
| 11.0 | 450.36.06 | June 2020 |
| 10.2 | 440.33 | Nov 2019 |

**Rule:** Container CUDA ≤ Host driver max CUDA

---

## GPU Architecture ↔ CUDA Version

| Architecture | Compute Capability | Min CUDA | Notes |
|-------------|-------------------|----------|-------|
| Blackwell | 10.0 | 12.0 | B100, B200 - latest |
| Hopper | 9.0 | 11.8 | H100, H200 |
| Ada Lovelace | 8.9 | 11.8 | RTX 4090, L4, L40 |
| Ampere | 8.6, 8.0 | 11.0 | A100, A40, RTX 3090 |
| Turing | 7.5 | 10.0 | T4, RTX 2080 |
| Volta | 7.0 | 9.0 | V100 |
| Pascal | 6.x | 8.0 | P100, GTX 1080 |
| Maxwell | 5.x | 6.5 | Older datacenter GPUs |
| Kepler | 3.x | 6.0 | Deprecated in CUDA 12.x |

---

## PyTorch ↔ CUDA Version

| PyTorch Version | CUDA Versions | Default Index URL |
|----------------|---------------|-------------------|
| 2.5.x | 12.6, 12.4, 11.8 | `cu124`, `cu126`, `cu118` |
| 2.4.x | 12.4, 12.1, 11.8 | `cu124`, `cu121`, `cu118` |
| 2.3.x | 12.1, 11.8 | `cu121`, `cu118` |
| 2.2.x | 12.1, 11.8 | `cu121`, `cu118` |
| 2.1.x | 12.1, 11.8 | `cu121`, `cu118` |
| 2.0.x | 11.8, 11.7 | `cu118`, `cu117` |

### Installation Commands

```bash
# CUDA 12.4 (recommended for modern GPUs)
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu124

# CUDA 12.6 (cutting edge)
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu126

# CUDA 11.8 (maximum compatibility)
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu118

# CPU only
pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu
```

---

## Cloud Platform Constraints

### Google Cloud Vertex AI

| Feature | Max CUDA | Notes |
|---------|----------|-------|
| Custom Training | 12.4 | Use `nvidia/cuda:12.4.x` base images |
| Pre-built Containers | 12.1 | Check latest versions |
| Workbench | 12.4 | Supports custom containers |

**Recommended base:** `nvidia/cuda:12.4.1-runtime-ubuntu22.04`

### AWS SageMaker

| Feature | Max CUDA | Notes |
|---------|----------|-------|
| Training DLCs | 12.1 | Deep Learning Containers |
| Custom Containers | 12.4 | Bring your own container |

**Recommendation:** Use SageMaker DLCs unless you need specific versions.

### RunPod / Vast.ai

| Feature | Max CUDA | Notes |
|---------|----------|-------|
| Custom Images | 12.6 | Usually latest CUDA supported |

**Recommendation:** Use latest stable (CUDA 12.4+) for best performance.

---

## Common Compatibility Issues

### Issue: `CUDA error: no kernel image is available`
**Cause:** PyTorch compiled for wrong CUDA architecture
**Fix:** Install PyTorch matching your GPU's compute capability

```bash
# Check your compute capability
nvidia-smi --query-gpu=compute_cap --format=csv

# A100 (8.0) - any CUDA 11.0+
# H100 (9.0) - CUDA 11.8+
# RTX 4090 (8.9) - CUDA 11.8+
```

### Issue: `Failed to initialize NVML`
**Cause:** Container CUDA > host driver max CUDA
**Fix:** Downgrade container CUDA or upgrade host driver

```bash
# Check host max CUDA
nvidia-smi | grep "CUDA Version"

# Container must use ≤ this version
```

### Issue: `libcuda.so.1: cannot open shared object`
**Cause:** Using `runtime` base instead of `devel` for builds
**Fix:** Use `-devel` for builder stage, `-runtime` for final

---

## Docker Base Images

```
nvidia/cuda:12.4.1-devel-ubuntu22.04   # Build stage (includes nvcc)
nvidia/cuda:12.4.1-runtime-ubuntu22.04 # Runtime stage (smaller)
nvidia/cuda:12.4.1-base-ubuntu22.04    # Minimal (no CUDA libs)
```

**Tags explained:**
- `devel`: Full CUDA toolkit (nvcc, headers, static libs) - ~4GB
- `runtime`: Runtime libraries only - ~1.5GB
- `base`: CUDA driver only - ~200MB

---

## Official Documentation

- [NVIDIA CUDA Compatibility](https://docs.nvidia.com/deploy/cuda-compatibility/)
- [CUDA Toolkit Release Notes](https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/)
- [PyTorch Installation](https://pytorch.org/get-started/locally/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)