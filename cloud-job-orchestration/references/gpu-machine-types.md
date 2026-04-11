# GPU Machine Type Reference

## A3 Series (NVIDIA H100 / H200)
Latest generation GPU machines with GPUDirect support.

| Machine Type | GPUs | GPU Memory | vCPUs | RAM | Network | Best For |
|--------------|------|------------|-------|-----|---------|----------|
| `a3-highgpu-1g` | 1x H100 80GB | 80 GB | 12 | 170 GB | 100 Gbps | Single-GPU LLM fine-tuning |
| `a3-highgpu-2g` | 2x H100 80GB | 160 GB | 24 | 340 GB | 200 Gbps | Medium distributed training |
| `a3-highgpu-4g` | 4x H100 80GB | 320 GB | 48 | 680 GB | 400 Gbps | Large-scale training |
| `a3-highgpu-8g` | 8x H100 80GB | 640 GB | 96 | 1360 GB | 800 Gbps | Full-node training |
| `a3-megagpu-8g` | 8x H100 Mega | 640 GB | 96 | 1360 GB | 1600 Gbps | Multi-node with GPUDirect-TCPXO |
| `a3-ultragpu-8g` | 8x H200 141GB | 1128 GB | 208 | 2048 GB | 3200 Gbps | Largest models, GPUDirect-RDMA |

**Notes:**
- H100 Mega has enhanced memory bandwidth
- H200 has 141GB HBM3e memory per GPU
- A3 Mega and A3 Ultra support GPUDirect-TCPXO/RDMA

## A2 Series (NVIDIA A100)
Previous generation, widely available.

| Machine Type | GPUs | GPU Memory | vCPUs | RAM | Best For |
|--------------|------|------------|-------|-----|----------|
| `a2-highgpu-1g` | 1x A100 40GB | 40 GB | 12 | 170 GB | Standard training |
| `a2-highgpu-2g` | 2x A100 40GB | 80 GB | 24 | 340 GB | Multi-GPU training |
| `a2-highgpu-4g` | 4x A100 40GB | 160 GB | 48 | 680 GB | Distributed training |
| `a2-highgpu-8g` | 8x A100 40GB | 320 GB | 96 | 1360 GB | Large-scale distributed |
| `a2-ultragpu-1g` | 1x A100 80GB | 80 GB | 12 | 170 GB | Large model training |
| `a2-ultragpu-2g` | 2x A100 80GB | 160 GB | 24 | 340 GB | Memory-intensive workloads |
| `a2-ultragpu-4g` | 4x A100 80GB | 320 GB | 48 | 680 GB | High-memory distributed |
| `a2-ultragpu-8g` | 8x A100 80GB | 640 GB | 96 | 1360 GB | Maximum A100 capacity |
| `a2-megagpu-16g` | 16x A100 40GB | 640 GB | 96 | 1360 GB | Maximum GPU density |

## G2 Series (NVIDIA L4)
Cost-effective for inference and light training.

| Machine Type | GPUs | GPU Memory | vCPUs | RAM | Best For |
|--------------|------|------------|-------|-----|----------|
| `g2-standard-4` | 1x L4 | 24 GB | 4 | 16 GB | Inference, prototyping |
| `g2-standard-8` | 1x L4 | 24 GB | 8 | 32 GB | Light training |
| `g2-standard-12` | 1x L4 | 24 GB | 12 | 48 GB | Medium workloads |
| `g2-standard-16` | 1x L4 | 24 GB | 16 | 64 GB | Training + inference |
| `g2-standard-24` | 2x L4 | 48 GB | 24 | 96 GB | Multi-GPU training |
| `g2-standard-48` | 4x L4 | 96 GB | 48 | 192 GB | Multi-GPU distributed |
| `g2-standard-96` | 8x L4 | 192 GB | 96 | 384 GB | Maximum L4 capacity |

## G4 Series (NVIDIA L40S)

| Machine Type | GPUs | GPU Memory | vCPUs | RAM | Best For |
|--------------|------|------------|-------|-----|----------|
| `g4-standard-48` | 1x L40S | 48 GB | 48 | 192 GB | High-performance inference |
| `g4-standard-96` | 2x L40S | 96 GB | 96 | 384 GB | Training and inference |
| `g4-standard-192` | 4x L40S | 192 GB | 192 | 768 GB | Multi-GPU workloads |
| `g4-standard-384` | 8x L40S | 384 GB | 384 | 1536 GB | Large-scale workloads |

## N1 Series (Attachable GPUs)
General-purpose machines with attachable GPUs. **Compatible GPUs:** T4, P4, V100, P100

| Machine Type | vCPUs | RAM | Max GPUs | Notes |
|--------------|-------|-----|----------|-------|
| `n1-standard-4` | 4 | 15 GB | 1–4 | Small experiments |
| `n1-standard-8` | 8 | 30 GB | 1–4 | Development |
| `n1-standard-16` | 16 | 60 GB | 1–4 | Medium workloads |
| `n1-standard-32` | 32 | 120 GB | 2–8 | Production training |
| `n1-highmem-8` | 8 | 52 GB | 1–4 | Memory-optimized |
| `n1-highmem-32` | 32 | 208 GB | 2–8 | Memory-optimized |

## TPU Machine Types

| Machine Type | TPU Chips | vCPUs | RAM |
|--------------|-----------|-------|-----|
| `ct5lp-hightpu-1t` | 1 | 24 | 48 GB |
| `ct5lp-hightpu-4t` | 4 | 112 | 192 GB |
| `ct5lp-hightpu-8t` | 8 | 224 | 384 GB |
| `ct6e-standard-1t` | 1 | 44 | 48 GB |
| `ct6e-standard-4t` | 4 | 180 | 720 GB |
| `ct6e-standard-8t` | 8 | 180 | 1440 GB |

---

## Accelerator Type Strings

Use these in `accelerator_type` when attaching GPUs to N1 machines or in SDK calls:

| String | GPU |
|--------|-----|
| `NVIDIA_TESLA_T4` | T4 16GB |
| `NVIDIA_TESLA_V100` | V100 16GB |
| `NVIDIA_TESLA_P100` | P100 16GB |
| `NVIDIA_TESLA_A100` | A100 40GB |
| `NVIDIA_A100_80GB` | A100 80GB |
| `NVIDIA_H100_80GB` | H100 80GB |
| `NVIDIA_L4` | L4 24GB |

---

## Selection Quick Reference

### By Use Case

| Use Case | Recommended | Machine Type |
|----------|-------------|-------------|
| Fine-tune ≤7B | L4 | `g2-standard-8` |
| Fine-tune 7B–13B | A100 40GB | `a2-highgpu-1g` |
| Fine-tune 13B–70B | A100 80GB | `a2-ultragpu-1g` |
| Fine-tune >70B | 8× H100 | `a3-highgpu-8g` |
| Inference (large) | A100 80GB | `a2-ultragpu-1g` |
| Inference (medium) | L4 | `g2-standard-4` |
| Budget experiments | T4 | `n1-standard-8` + T4 |

### By Budget

| Budget Level | Strategy | Expected Cost |
|-------------|----------|---------------|
| Low (<$100) | Spot L4/T4 | $0.10–0.25/hr |
| Medium ($100–500) | Spot A100 | $0.75–1.10/hr |
| High ($500–2000) | On-demand A100, Spot H100 | $2–5/hr |
| Enterprise (>$2000) | On-demand H100, CUDs | $2–5/hr with commitment |
