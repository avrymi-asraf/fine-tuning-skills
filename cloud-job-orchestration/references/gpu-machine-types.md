# GPU Machine Type Reference

## Vertex AI Machine Types

### A3 Series (NVIDIA H100 / H200)
Latest generation GPU machines with GPUDirect support.

| Machine Type | GPUs | GPU Memory | vCPUs | RAM | Network | Best For |
|--------------|------|------------|-------|-----|---------|----------|
| `a3-highgpu-1g` | 1x H100 80GB | 80 GB | 12 | 170 GB | 100 Gbps | Single-GPU LLM fine-tuning |
| `a3-highgpu-2g` | 2x H100 80GB | 160 GB | 24 | 340 GB | 200 Gbps | Medium distributed training |
| `a3-highgpu-4g` | 4x H100 80GB | 320 GB | 48 | 680 GB | 400 Gbps | Large-scale training |
| `a3-highgpu-8g` | 8x H100 80GB | 640 GB | 96 | 1360 GB | 800 Gbps | Full-node training |
| `a3-megagpu-8g` | 8x H100 Mega | 640 GB | 96 | 1360 GB | 1600 Gbps | Multi-node with GPUDirect-TCPXO |
| `a3-ultragpu-8g` | 8x H200 141GB | 1128 GB | 208 | 2048 GB | 3200 Gbps | Largest models, GPUDirect-RDMA |
| `a4-highgpu-8g` | 8x B200 | 1536 GB | 208 | 2048 GB | 3200 Gbps | Next-gen with GPUDirect-RDMA |
| `a4x-highgpu-4g` | 4x GB200 | 768 GB | 104 | 1024 GB | 2400 Gbps | High-performance with RDMA |

**Notes:**
- H100 Mega has enhanced memory bandwidth
- H200 has 141GB HBM3e memory per GPU
- A3 Mega and A3 Ultra support GPUDirect-TCPXO
- A4 and A4X support GPUDirect-RDMA over RoCE

### A2 Series (NVIDIA A100)
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

### G2 Series (NVIDIA L4)
Cost-effective for inference and light training.

| Machine Type | GPUs | GPU Memory | vCPUs | RAM | Best For |
|--------------|------|------------|-------|-----|----------|
| `g2-standard-4` | 1x L4 | 24 GB | 4 | 16 GB | Inference, prototyping |
| `g2-standard-8` | 1x L4 | 24 GB | 8 | 32 GB | Light training |
| `g2-standard-12` | 1x L4 | 24 GB | 12 | 48 GB | Medium workloads |
| `g2-standard-16` | 1x L4 | 24 GB | 16 | 64 GB | Training + inference |
| `g2-standard-24` | 2x L4 | 48 GB | 24 | 96 GB | Multi-GPU training |
| `g2-standard-32` | 1x L4 | 24 GB | 32 | 128 GB | CPU-heavy + GPU |
| `g2-standard-48` | 4x L4 | 96 GB | 48 | 192 GB | Multi-GPU distributed |
| `g2-standard-96` | 8x L4 | 192 GB | 96 | 384 GB | Maximum L4 capacity |

### G4 Series (NVIDIA L40S)
Next-gen inference/training GPU.

| Machine Type | GPUs | GPU Memory | vCPUs | RAM | Best For |
|--------------|------|------------|-------|-----|----------|
| `g4-standard-48` | 1x L40S | 48 GB | 48 | 192 GB | High-performance inference |
| `g4-standard-96` | 2x L40S | 96 GB | 96 | 384 GB | Training and inference |
| `g4-standard-192` | 4x L40S | 192 GB | 192 | 768 GB | Multi-GPU workloads |
| `g4-standard-384` | 8x L40S | 384 GB | 384 | 1536 GB | Large-scale workloads |

### N1 Series (Attachable GPUs)
General-purpose machines with attachable GPUs.

**Compatible GPUs:** T4, P4, V100, P100

| Machine Type | vCPUs | RAM | Max GPUs | Notes |
|--------------|-------|-----|----------|-------|
| `n1-standard-4` | 4 | 15 GB | 1, 2, 4 | Small experiments |
| `n1-standard-8` | 8 | 30 GB | 1, 2, 4 | Development |
| `n1-standard-16` | 16 | 60 GB | 1, 2, 4 | Medium workloads |
| `n1-standard-32` | 32 | 120 GB | 2, 4, 8 | Production training |
| `n1-standard-64` | 64 | 240 GB | 4, 8 | Large workloads |
| `n1-standard-96` | 96 | 360 GB | 4, 8 | Maximum N1 |
| `n1-highmem-2` | 2 | 13 GB | 1, 2, 4 | Memory-optimized |
| `n1-highmem-4` | 4 | 26 GB | 1, 2, 4 | Memory-optimized |
| `n1-highmem-8` | 8 | 52 GB | 1, 2, 4 | Memory-optimized |
| `n1-highmem-16` | 16 | 104 GB | 1, 2, 4 | Memory-optimized |
| `n1-highmem-32` | 32 | 208 GB | 2, 4, 8 | Memory-optimized |
| `n1-highmem-64` | 64 | 416 GB | 4, 8 | Memory-optimized |
| `n1-highmem-96` | 96 | 624 GB | 4, 8 | Memory-optimized |

### TPU Machine Types

| Machine Type | TPU Chips | vCPUs | RAM | Topology Options |
|--------------|-----------|-------|-----|------------------|
| `ct5lp-hightpu-1t` | 1 | 24 | 48 GB | 1x1 |
| `ct5lp-hightpu-4t` | 4 | 112 | 192 GB | 2x2, 2x4, 4x4, 4x8, 8x8, 8x16, 16x16 |
| `ct5lp-hightpu-8t` | 8 | 224 | 384 GB | 2x4 |
| `ct6e-standard-1t` | 1 | 44 | 48 GB | 1x1 |
| `ct6e-standard-4t` | 4 | 180 | 720 GB | 2x2, 2x4, 4x4, 4x8, 8x8, 8x16, 16x16 |
| `ct6e-standard-8t` | 8 | 180 | 1440 GB | 2x4 |
| `tpu7x-standard-4t` | 4 | Varies | Varies | 2x2x1, 2x2x2, 2x2x4, etc. |

---

## AWS SageMaker Instance Types

### P5 Series (NVIDIA H100)
| Instance Type | GPUs | GPU Memory | vCPUs | RAM | Network |
|---------------|------|------------|-------|-----|---------|
| `ml.p5.48xlarge` | 8x H100 | 640 GB | 192 | 2 TB | 3200 Gbps |
| `ml.p5e.48xlarge` | 8x H100 | 640 GB | 192 | 2 TB | 3200 Gbps |

### P4 Series (NVIDIA A100)
| Instance Type | GPUs | GPU Memory | vCPUs | RAM | Network |
|---------------|------|------------|-------|-----|---------|
| `ml.p4d.24xlarge` | 8x A100 40GB | 320 GB | 96 | 1.1 TB | 400 Gbps |
| `ml.p4de.24xlarge` | 8x A100 80GB | 640 GB | 96 | 1.1 TB | 400 Gbps |

### P3 Series (NVIDIA V100)
| Instance Type | GPUs | GPU Memory | vCPUs | RAM |
|---------------|------|------------|-------|-----|
| `ml.p3.2xlarge` | 1x V100 | 16 GB | 8 | 61 GB |
| `ml.p3.8xlarge` | 4x V100 | 64 GB | 32 | 244 GB |
| `ml.p3.16xlarge` | 8x V100 | 128 GB | 64 | 488 GB |
| `ml.p3dn.24xlarge` | 8x V100 | 128 GB | 96 | 768 GB |

### G5 Series (NVIDIA A10G)
| Instance Type | GPUs | GPU Memory | vCPUs | RAM |
|---------------|------|------------|-------|-----|
| `ml.g5.xlarge` | 1x A10G | 24 GB | 4 | 16 GB |
| `ml.g5.2xlarge` | 1x A10G | 24 GB | 8 | 32 GB |
| `ml.g5.4xlarge` | 1x A10G | 24 GB | 16 | 64 GB |
| `ml.g5.8xlarge` | 1x A10G | 24 GB | 32 | 128 GB |
| `ml.g5.12xlarge` | 4x A10G | 96 GB | 48 | 192 GB |
| `ml.g5.16xlarge` | 1x A10G | 24 GB | 64 | 256 GB |
| `ml.g5.24xlarge` | 4x A10G | 96 GB | 96 | 384 GB |
| `ml.g5.48xlarge` | 8x A10G | 192 GB | 192 | 768 GB |

### G6 Series (NVIDIA L4/L40S)
| Instance Type | GPUs | GPU Memory | vCPUs | RAM |
|---------------|------|------------|-------|-----|
| `ml.g6.xlarge` | 1x L4 | 24 GB | 4 | 16 GB |
| `ml.g6.2xlarge` | 1x L4 | 24 GB | 8 | 32 GB |
| `ml.g6e.xlarge` | 1x L40S | 48 GB | 8 | 32 GB |

---

## RunPod GPU Types

### High-End Training GPUs
| GPU Type | Memory | Best For | Preemption Risk |
|----------|--------|----------|-----------------|
| NVIDIA H100 80GB HBM3 | 80 GB | Large LLM training | High |
| NVIDIA H100 NVL | 94 GB | Multi-GPU training | High |
| NVIDIA A100 80GB PCIe | 80 GB | Training, inference | Medium |
| NVIDIA A100-SXM4-80GB | 80 GB | High-performance training | Medium |

### Mid-Range GPUs
| GPU Type | Memory | Best For | Preemption Risk |
|----------|--------|----------|-----------------|
| NVIDIA RTX A6000 | 48 GB | Training, inference | Low |
| NVIDIA L40S | 48 GB | Inference, fine-tuning | Low |
| NVIDIA A40 | 48 GB | Training, rendering | Low |
| NVIDIA A10 | 24 GB | Inference, light training | Low |

### Consumer GPUs (Cost-Effective)
| GPU Type | Memory | Best For | Preemption Risk |
|----------|--------|----------|-----------------|
| NVIDIA RTX 4090 | 24 GB | Fine-tuning, inference | Very Low |
| NVIDIA RTX 3090 | 24 GB | Fine-tuning, inference | Very Low |
| NVIDIA RTX 4080 | 16 GB | Inference, prototyping | Very Low |
| NVIDIA RTX 3080 | 10 GB | Inference, prototyping | Very Low |

---

## GPU Selection Quick Reference

### By Use Case

| Use Case | Recommended GPU | Vertex AI | SageMaker | RunPod |
|----------|----------------|-----------|-----------|--------|
| LLM Training (>70B) | H100 80GB | a3-highgpu-8g | ml.p5.48xlarge | H100 80GB |
| LLM Training (7B-70B) | A100 80GB | a2-ultragpu-8g | ml.p4de.24xlarge | A100 80GB |
| Fine-tuning (7B-13B) | A100 40GB | a2-highgpu-1g | ml.p4d.24xlarge | A100 40GB |
| Fine-tuning (<7B) | L4/L40S | g2-standard-4 | ml.g6.xlarge | L40S |
| Inference (Large) | A100 80GB | a2-ultragpu-1g | ml.g5.48xlarge | A100 80GB |
| Inference (Medium) | L4/T4 | g2-standard-4 | ml.g5.xlarge | L4 |
| Inference (Small) | T4 | n1 + T4 | ml.g4dn.xlarge | RTX 4090 |
| Multi-GPU Distributed | H100/A100 | a3-highgpu-8g | ml.p5.48xlarge | Multiple |

### By Budget

| Budget Level | Strategy | Expected Cost |
|--------------|----------|---------------|
| Very Low (<$100) | RunPod RTX 3090/4090 | $0.50-0.70/hr |
| Low ($100-500) | Spot VMs on G2/L4 | $0.20-0.80/hr |
| Medium ($500-2000) | Spot A100, On-demand L4 | $1-4/hr |
| High ($2000-10000) | On-demand A100, Spot H100 | $3-15/hr |
| Enterprise (>$10000) | On-demand H100, CUDs | $2-5/hr with commitment |
