# Gemma GPU VM Terraform Module

Deploys a GPU-enabled Compute Engine VM optimized for running Gemma 4 models with Unsloth.

## Quick Start

1. **Copy and edit the variables file:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your project_id and preferred settings
   ```

2. **Initialize and apply:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Connect to your VM:**
   ```bash
   # Use the output command
   $(terraform output -raw ssh_command)
   
   # Or directly
   gcloud compute ssh $(terraform output -raw instance_name) --zone=$(terraform output -raw zone) --tunnel-through-iap
   ```

## Variables

| Name | Description | Default |
|------|-------------|---------|
| `project_id` | GCP project ID (required) | - |
| `region` | GCP region | `us-central1` |
| `zone` | GCP zone | `us-central1-a` |
| `instance_name` | VM name | `gemma-gpu-vm` |
| `machine_type` | Machine type | `n1-standard-4` |
| `gpu_type` | GPU type | `nvidia-tesla-t4` |
| `gpu_count` | Number of GPUs | `1` |
| `use_spot` | Use spot instances (cheaper) | `false` |
| `boot_disk_size` | Disk size in GB | `100` |
| `create_gcs_bucket` | Create GCS bucket | `true` |

### GPU Options

| GPU Type | VRAM | Best For |
|----------|------|----------|
| `nvidia-tesla-t4` | 16 GB | Gemma 4 E2B/4B |
| `nvidia-l4` | 24 GB | Gemma 4 4B (comfortable) |
| `nvidia-a100-40gb` | 40 GB | Gemma 4 26B/31B (with quantization) |
| `nvidia-a100-80gb` | 80 GB | Gemma 4 26B/31B |

## Outputs

After `terraform apply`, you'll get:

- `ssh_command` — Command to SSH into the instance
- `gcs_bucket_url` — GCS bucket for data storage
- `connection_instructions` — Full connection guide

## Cost Optimization

Enable spot instances for 60-90% savings:

```hcl
use_spot = true
```

**Warning:** Spot VMs can be preempted. Save checkpoints frequently during training.

## Cleanup

```bash
terraform destroy
```

This removes the VM but keeps the GCS bucket (unless `force_destroy = true`).
