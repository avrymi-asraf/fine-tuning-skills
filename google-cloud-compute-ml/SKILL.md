---
name: google-cloud-compute-ml
description: Deploy and run ML models on Google Cloud compute infrastructure. Covers Compute Engine GPU instances, SSH connectivity, file transfers from local machines, environment setup (CUDA, Unsloth), and VM lifecycle management for fine-tuning workflows. Use when the user wants to run models on GCP, create GPU VMs, upload models/data from their computer, SSH into instances, or set up training environments for Gemma 4.
---

<google-cloud-compute-ml>
Deploy and manage GPU-enabled compute instances for ML workloads on Google Cloud. This skill bridges infrastructure setup (`cloud-infrastructure-setup`) and actual model training.

**Workflow:** Create GPU VM → Connect/transfer files → Setup environment → Run training → Stop to save money

**Deployment options:**
- **Compute Engine + GPU** (primary) — Full control, best for Unsloth fine-tuning
- **Vertex AI Workbench** (alternative) — Managed notebooks

**Scripts:** Seven bash scripts in `scripts/` handle all operations. Run any script without arguments to see available commands.

**Prerequisites:** Complete `cloud-infrastructure-setup` skill first — authenticated gcloud CLI, project with billing, enabled APIs.

</google-cloud-compute-ml>

<compute-instances>
Create and manage GPU-enabled VMs for ML workloads.

```bash
# Create GPU VM
./scripts/gcp_compute.sh create <name> [options]
  --gpu-type=nvidia-tesla-t4    # T4 (16GB), L4 (24GB), A100 (40/80GB)
  --machine-type=n1-standard-4  # 4 vCPU, 15GB RAM
  --region=us-central1
  --spot                        # 60-90% cheaper, can be preempted

# Lifecycle
./scripts/gcp_compute.sh list    # Show instances with GPU info
./scripts/gcp_compute.sh stop <name>
./scripts/gcp_compute.sh start <name>
./scripts/gcp_compute.sh delete <name>
```

**Example:**
```bash
./scripts/gcp_compute.sh create gemma-trainer \
  --gpu-type=nvidia-tesla-t4 \
  --machine-type=n1-standard-4
```

Deep Learning VM images (pre-installed CUDA, PyTorch) are used by default. See `reference.md` for GPU specs.

</compute-instances>

<ssh-connectivity>
Connect to VMs via IAP (no public IP needed).

```bash
./scripts/gcp_ssh.sh connect <instance> [ --region=<region> ]     # Interactive SSH
./scripts/gcp_ssh.sh command <instance> "nvidia-smi"              # Run command
./scripts/gcp_ssh.sh tunnel <instance> \                          # Port forward
  --local-port=8888 --remote-port=8888
```

Use `tmux` or `screen` inside VMs for persistent sessions.

</ssh-connectivity>

<file-transfer>
Upload models and data from local machine to GCP VMs.

```bash
# Direct SCP (good for <1GB)
./scripts/gcp_transfer.sh upload <local-path> <instance>:<remote-path>
./scripts/gcp_transfer.sh download <instance>:<remote-path> <local-path>

# Via GCS (better for >1GB)
./scripts/gcp_transfer.sh sync-up <local-dir> gs://my-bucket/path/
./scripts/gcp_transfer.sh sync-down gs://my-bucket/path/ <local-dir>
```

</file-transfer>

<environment-setup>
Set up the ML environment on your GPU VM.

```bash
./scripts/gcp_setup.sh cuda-check        # Verify GPU/CUDA
./scripts/gcp_setup.sh install-unsloth   # Install Unsloth + dependencies
./scripts/gcp_setup.sh install-ollama    # For inference
./scripts/gcp_setup.sh install-jupyter   # JupyterLab on port 8888
```

</environment-setup>

<gemma-4-workflow>
Run Gemma 4 models with Unsloth for fine-tuning.

### Model Size vs GPU Requirements
| Model | VRAM Required | Minimum GPU |
|-------|---------------|-------------|
| Gemma 4 E2B | ~5GB | T4 (16GB) |
| Gemma 4 4B | ~10GB | T4 (16GB) |
| Gemma 4 26B | ~60GB | A100 (80GB) |
| Gemma 4 31B | ~70GB | A100 (80GB) |

### Quick Start
```bash
# 1. Create VM
./scripts/gcp_compute.sh create gemma-trainer --gpu-type=nvidia-tesla-t4

# 2. Upload data
./scripts/gcp_transfer.sh upload ./training-data.jsonl gemma-trainer:/home/$USER/data/

# 3. Connect and setup
./scripts/gcp_ssh.sh connect gemma-trainer
./scripts/gcp_setup.sh install-unsloth

# 4. Fine-tune
./scripts/gcp_gemma.sh finetune \
  --model=unsloth/gemma-4-4b \
  --dataset=/home/$USER/data/train.jsonl \
  --4bit
```

</gemma-4-workflow>

<vertex-ai-workbench>
Alternative: Managed Jupyter notebooks with less setup.

### Workbench vs Compute Engine
| Factor | Workbench | Compute Engine |
|--------|-----------|----------------|
| Setup | Minimal | Manual |
| Control | Limited | Full (root) |
| Unsloth | Custom container | Direct install |
| Best for | Quick experiments | Full pipelines |

```bash
./scripts/gcp_workbench.sh create <name> --gpu-type=T4
./scripts/gcp_workbench.sh open <name>  # Opens Jupyter in browser
```

</vertex-ai-workbench>

<cost-management>
Control cloud costs for GPU workloads.

```bash
./scripts/gcp_cost.sh estimate --gpu-type=nvidia-tesla-t4 --hours-per-day=8
./scripts/gcp_cost.sh schedule-stop <instance> --after-hours=8
./scripts/gcp_cost.sh report
```

**Cost estimates (us-central1):**
| GPU | Per Hour | Per Day (8h) | Per Week (40h) |
|-----|----------|--------------|----------------|
| T4 | ~$0.35 | ~$2.80 | ~$14 |
| L4 | ~$0.75 | ~$6.00 | ~$30 |
| A100 40GB | ~$2.50 | ~$20 | ~$100 |

**Stop instances when not training** — you pay for GPUs only while running.

</cost-management>

<terraform-deployment>
Reproducible infrastructure-as-code deployments.

```bash
cd terraform/gemma-gpu-vm
cp terraform.tfvars.example terraform.tfvars
# Edit with your project_id

terraform init
terraform apply
```

Outputs include SSH command, GCS bucket URL, and connection instructions.

</terraform-deployment>

<google-cloud-compute-ml-scripts>
All scripts in `scripts/` are self-documenting. Run without arguments to see commands.

| Script | Purpose |
|--------|---------|
| `gcp_compute.sh` | VM lifecycle: create, start, stop, delete, list, status |
| `gcp_ssh.sh` | SSH: connect, command, tunnel |
| `gcp_transfer.sh` | File transfer: upload, download, sync-up, sync-down |
| `gcp_setup.sh` | Environment: cuda-check, install-unsloth, install-ollama, install-jupyter |
| `gcp_gemma.sh` | Gemma: finetune, download, serve |
| `gcp_workbench.sh` | Workbench: create, delete, list, open, start, stop |
| `gcp_cost.sh` | Cost: estimate, schedule-stop, cancel-schedule, report |

</google-cloud-compute-ml-scripts>

<google-cloud-compute-ml-reference>
See `reference.md` for:
- GPU specifications and regional availability
- Gemma 4 memory requirements
- gcloud command reference
- Troubleshooting common errors

</google-cloud-compute-ml-reference>

<examples>

### Complete Workflow: Fine-tune Gemma 4 4B

```bash
# Prerequisites: gcloud authenticated, project with billing

# 1. Create GPU VM
./scripts/gcp_compute.sh create gemma-trainer \
  --gpu-type=nvidia-tesla-t4 --machine-type=n1-standard-4

# 2. Upload dataset
./scripts/gcp_transfer.sh upload ./train.jsonl gemma-trainer:/home/$USER/data/

# 3. SSH and setup
./scripts/gcp_ssh.sh connect gemma-trainer
# Inside VM:
./scripts/gcp_setup.sh install-unsloth

# 4. Fine-tune with Unsloth
./scripts/gcp_gemma.sh finetune \
  --model=unsloth/gemma-4-4b \
  --dataset=/home/$USER/data/train.jsonl \
  --epochs=3 --4bit

# 5. Download results
./scripts/gcp_transfer.sh download gemma-trainer:/home/$USER/output/ ./results/

# 6. Stop to save money
./scripts/gcp_compute.sh stop gemma-trainer
```

### Terraform for Team Setup

```bash
cd terraform/gemma-gpu-vm
cat > terraform.tfvars << EOF
project_id = "my-project"
region     = "us-central1"
gpu_type   = "nvidia-tesla-t4"
use_spot   = true
EOF

terraform init
terraform apply
ssh -i ~/.ssh/google_compute_engine $(terraform output -raw ssh_command)
```

</examples>

<common-mistakes>

- **Wrong region for GPU** — Not all GPUs available everywhere. Check `reference.md`.
- **Forgot to stop instance** — GPUs are expensive. Always stop when done.
- **Uploading large files via SCP** — Use GCS for files >1GB.
- **OOM errors** — Gemma 4 26B/31B need A100. Won't fit on T4/L4.
- **Missing APIs** — Ensure Compute Engine API is enabled.
- **Permission denied on SSH** — Use IAP: `./scripts/gcp_ssh.sh connect <name>`

</common-mistakes>

<checklist>

### Before Creating VM
- [ ] Project has billing enabled
- [ ] Compute Engine API enabled
- [ ] GPU quota available in target region
- [ ] Model/data ready for upload

### After VM Creation
- [ ] Can SSH: `./scripts/gcp_ssh.sh connect <name>`
- [ ] GPU visible: `./scripts/gcp_ssh.sh command <name> "nvidia-smi"`
- [ ] Environment ready: `./scripts/gcp_setup.sh cuda-check`

### Cost Management
- [ ] Instance stopped when not in use
- [ ] Spot instances used if workload supports interruption

</checklist>
