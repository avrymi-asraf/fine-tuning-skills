# Google Cloud Compute ML Reference

## GPU Specifications

### NVIDIA GPUs on GCP

| GPU Type | VRAM | Best For | Approx. Cost/hr (us-central1) |
|----------|------|----------|-------------------------------|
| nvidia-tesla-t4 | 16 GB | Inference, small training, Gemma 4 E2B/4B | ~$0.35 |
| nvidia-l4 | 24 GB | Training, larger models | ~$0.75 |
| nvidia-a100-40gb | 40 GB | Large model training | ~$2.50 |
| nvidia-a100-80gb | 80 GB | Largest models, Gemma 4 26B/31B | ~$3.67 |

### GPU Availability by Region

Not all GPUs are available in all regions. Check with:
```bash
gcloud compute accelerator-types list --filter="name:nvidia-tesla-t4"
```

Common regions with good GPU availability:
- `us-central1` (Iowa) — Most GPU types
- `us-west1` (Oregon) — Most GPU types
- `europe-west4` (Netherlands) — Good for EU
- `asia-east1` (Taiwan) — Good for APAC

### Machine Types for GPUs

GPUs attach to N1 machine family (except A2 for A100):

| Machine Type | vCPUs | Memory | Max GPUs |
|--------------|-------|--------|----------|
| n1-standard-4 | 4 | 15 GB | 1 |
| n1-standard-8 | 8 | 30 GB | 2 |
| n1-standard-16 | 16 | 60 GB | 4 |
| n1-standard-32 | 32 | 120 GB | 8 |
| n1-highmem-8 | 8 | 52 GB | 2 |
| n1-highmem-16 | 16 | 104 GB | 4 |

Rule of thumb: 1 GPU per 4 vCPUs minimum for training.

## Gemma 4 Model Requirements

### Memory Requirements (Unsloth)

| Model | Base VRAM | 4-bit Quantized | 8-bit Quantized |
|-------|-----------|-----------------|-----------------|
| Gemma 4 E2B | ~5 GB | ~3 GB | ~4 GB |
| Gemma 4 4B | ~10 GB | ~6 GB | ~8 GB |
| Gemma 4 26B | ~60 GB | ~35 GB | ~45 GB |
| Gemma 4 31B | ~70 GB | ~40 GB | ~55 GB |

### Recommended Configurations

| Model | GPU | Machine Type | Notes |
|-------|-----|--------------|-------|
| Gemma 4 E2B | T4 | n1-standard-4 | Fits comfortably |
| Gemma 4 4B | T4 | n1-standard-4 | Tight but works with 4-bit |
| Gemma 4 4B | L4 | n1-standard-4 | Recommended |
| Gemma 4 26B | A100 80GB | n1-standard-16 | Must use 4-bit or 8-bit |
| Gemma 4 31B | A100 80GB | n1-standard-16 | Must use 4-bit |

## Deep Learning VM Images

GCP provides pre-configured VM images with CUDA, PyTorch, TensorFlow:

```bash
# List available images
gcloud compute images list --project=deeplearning-platform-release --format="table(name)"
```

Common images:
- `c2-deeplearning-pytorch-2-2-cu121-v20240417` — PyTorch 2.2, CUDA 12.1
- `common-cu121-v20240417` — CUDA 12.1 base

## gcloud Command Reference

### Instances
```bash
# Create with GPU
gcloud compute instances create NAME \
  --zone=ZONE \
  --machine-type=MACHINE_TYPE \
  --accelerator=type=GPU_TYPE,count=1 \
  --image-family=common-cu121 \
  --image-project=deeplearning-platform-release \
  --boot-disk-size=100GB \
  --maintenance-policy=TERMINATE

# List instances
gcloud compute instances list

# Start/Stop
gcloud compute instances start NAME --zone=ZONE
gcloud compute instances stop NAME --zone=ZONE

# Delete
gcloud compute instances delete NAME --zone=ZONE
```

### SSH
```bash
# Connect with IAP
gcloud compute ssh NAME --zone=ZONE --tunnel-through-iap

# Run command
gcloud compute ssh NAME --zone=ZONE --command="nvidia-smi" --tunnel-through-iap

# Port forward
gcloud compute ssh NAME --zone=ZONE --tunnel-through-iap -- -L 8888:localhost:8888
```

### File Transfer
```bash
# Upload
gcloud compute scp LOCAL_PATH NAME:REMOTE_PATH --zone=ZONE --tunnel-through-iap

# Download
gcloud compute scp NAME:REMOTE_PATH LOCAL_PATH --zone=ZONE --tunnel-through-iap

# Recursive
gcloud compute scp --recurse LOCAL_DIR NAME:REMOTE_DIR --zone=ZONE --tunnel-through-iap
```

## Troubleshooting

### "Could not fetch resource"
**Cause:** GPU quota exceeded or not available in region  
**Fix:** Check quota: `gcloud compute regions describe REGION`

### "CUDA out of memory"
**Cause:** Model too large for GPU VRAM  
**Fix:** 
- Reduce batch size
- Enable gradient checkpointing
- Use 4-bit quantization: `load_in_4bit=True`
- Upgrade GPU (T4 → L4 → A100)

### "Permission denied (publickey)"
**Cause:** SSH key not recognized  
**Fix:**
- Use IAP: `--tunnel-through-iap`
- Add OS Login: `gcloud compute os-login ssh-keys add`
- Check firewall rules allow SSH (port 22)

### "Billing account not configured"
**Cause:** Project not linked to billing  
**Fix:** See `google-cloud-account` skill billing section

### "API not enabled"
**Cause:** Compute Engine API disabled  
**Fix:** `gcloud services enable compute.googleapis.com`

### Slow file transfers
**Cause:** SCP over IAP is slow  
**Fix:** Use GCS as intermediate:
```bash
gcloud storage cp LOCAL_FILE gs://BUCKET/
gcloud compute ssh NAME --command="gcloud storage cp gs://BUCKET/FILE REMOTE_PATH"
```

## Pricing Notes

- **GPUs:** Billed per second while instance is running
- **VM:** Billed separately from GPU (CPU, RAM, disk)
- **Disk:** Persistent SSD billed per GB-month, always (even when stopped)
- **Spot instances:** 60-90% discount, can be preempted
- **Sustained use discounts:** Automatic for standard instances running >25% of month

## Quota Limits

Default GPU quotas are typically 0 or very low. Request increases:

```bash
# Check current quota
gcloud compute regions describe REGION --format="table(quotas[].metric,quotas[].limit,quotas[].usage)"

# Request increase via Console:
# IAM & Admin > Quotas > Filter by metric (e.g., "NVIDIA T4 GPUs")
```

Request at least 1 GPU quota before starting.

## Security Best Practices

1. **Use IAP** — Don't expose VMs to public internet
2. **OS Login** — Centralized SSH key management
3. **Service accounts** — Use least-privilege service accounts for VMs
4. **Firewall rules** — Restrict SSH to specific IP ranges if needed
5. **Stop when done** — Reduces attack surface and saves money
