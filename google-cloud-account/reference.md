# Google Cloud Account Reference

Detailed reference information for GCP account management.

---

## Required APIs for Gemma 4 Fine-Tuning

Enable these APIs before starting fine-tuning workflows:

| API | Purpose |
|-----|---------|
| `aiplatform.googleapis.com` | Vertex AI platform services |
| `storage.googleapis.com` | Google Cloud Storage (checkpoints, datasets) |
| `compute.googleapis.com` | Compute Engine (GPU VMs) |
| `cloudbuild.googleapis.com` | Cloud Build (container builds) |
| `artifactregistry.googleapis.com` | Artifact Registry (custom containers) |
| `notebooks.googleapis.com` | Vertex AI Workbench (optional) |
| `logging.googleapis.com` | Cloud Logging (optional) |
| `monitoring.googleapis.com` | Cloud Monitoring (optional) |

Enable all at once:
```bash
gcloud services enable \
  aiplatform.googleapis.com \
  storage.googleapis.com \
  compute.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  --project=<PROJECT_ID>
```

---

## IAM Roles Reference

### Vertex AI Roles

| Role | Permissions |
|------|-------------|
| `roles/aiplatform.user` | Use endpoints, run predictions |
| `roles/aiplatform.admin` | Full Vertex AI control |
| `roles/aiplatform.viewer` | Read-only access |

### Storage Roles

| Role | Permissions |
|------|-------------|
| `roles/storage.objectAdmin` | Full object control (CRUD) |
| `roles/storage.objectViewer` | Read-only object access |
| `roles/storage.admin` | Full bucket and object control |

### Compute Roles

| Role | Permissions |
|------|-------------|
| `roles/compute.instanceAdmin.v1` | Create, delete, manage VMs |
| `roles/compute.osAdminLogin` | SSH as admin to VMs |
| `roles/compute.osLogin` | SSH to VMs |

### Billing Roles

| Role | Permissions |
|------|-------------|
| `roles/billing.admin` | Full billing control |
| `roles/billing.viewer` | View billing info |
| `roles/billing.costsManager` | View and export costs |

---

## Quota Types

### Compute Engine Regional Quotas

Check with:
```bash
gcloud compute regions describe <REGION> --project=<PROJECT_ID> --format="yaml(quotas)"
```

Key quotas for ML workloads:

| Quota | Description |
|-------|-------------|
| `CPUS` | Total vCPUs in region |
| `IN_USE_ADDRESSES` | Static/external IP addresses |
| `NVIDIA_A100_GPUS` | A100 GPU count |
| `NVIDIA_H100_GPUS` | H100 GPU count (if available) |
| `NVIDIA_L4_GPUS` | L4 GPU count |
| `NVIDIA_T4_GPUS` | T4 GPU count |
| `PREEMPTIBLE_CPUS` | Preemptible vCPUs |

### Requesting Quota Increases

1. Go to Cloud Console → IAM & Admin → Quotas
2. Filter by service (Compute Engine) and metric (GPUs)
3. Select quota and click "Edit Quotas"
4. Fill request form with business justification
5. Submit and wait 1–3 business days for approval

---

## Billing Account Format

Billing account IDs follow this pattern: `XXXXXX-XXXXXX-XXXXXX`

Find yours:
```bash
gcloud beta billing accounts list
```

Output:
```
ACCOUNT_ID            NAME                 OPEN  MASTER_ACCOUNT_ID
XXXXXX-XXXXXX-XXXXXX  My Billing Account   True
```

Use the `ACCOUNT_ID` in commands.

---

## gcloud Command Reference

### Global Flags

| Flag | Purpose |
|------|---------|
| `--project=<ID>` | Target specific project |
| `--quiet` (`-q`) | Suppress interactive prompts |
| `--format=json` | JSON output for scripting |
| `--verbosity=debug` | Detailed HTTP logs |
| `--log-http` | Log all HTTP traffic |

### Output Formats

```bash
--format="table(projectId,name)"      # Table format
--format="yaml"                       # YAML output
--format="json"                       # JSON output
--format="value(projectId)"           # Single value
```

---

## Common Errors and Solutions

### "Billing account not found"
**Cause:** Wrong billing account ID format  
**Fix:** Use `gcloud beta billing accounts list` to get exact ID

### "Project has no billing account"
**Cause:** Project not linked to billing  
**Fix:** Run `gcp_projects.sh billing_link <project> <account>`

### "API not enabled"
**Cause:** Required API not enabled for project  
**Fix:** Run `gcp_projects.sh apis_enable <project>`

### "Quota exceeded"
**Cause:** Regional quota limit reached  
**Fix:** Check quotas with `gcp_diagnose.sh quotas` and request increase

### "Permission denied"
**Cause:** IAM policy doesn't grant required role  
**Fix:** Use `gcp_iam.sh grant` to add appropriate role

### "ADC not found"
**Cause:** Application Default Credentials not configured  
**Fix:** Run `gcp_auth.sh adc`

---

## Regions and Zones

### GPU Availability by Region (as of 2025)

| Region | GPUs Available | Notes |
|--------|---------------|-------|
| `us-central1` | A100, L4, T4 | Good availability |
| `us-west1` | A100, L4, T4 | Good availability |
| `us-east1` | L4, T4 | Limited A100 |
| `europe-west4` | A100, L4, T4 | Netherlands |
| `europe-west1` | L4, T4 | Belgium |
| `asia-east1` | A100, T4 | Taiwan |

Check current availability:
```bash
gcloud compute accelerator-types list --filter="zone:us-central1-a"
```

### Setting Default Region/Zone

```bash
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-a
```

---

## Service Account Email Format

Service accounts use this email pattern:
```
<NAME>@<PROJECT_ID>.iam.gserviceaccount.com
```

Example:
```
gemma-training@my-project-123.iam.gserviceaccount.com
```

---

## Config Profiles

Configuration profiles store sets of gcloud settings.

List all settings:
```bash
gcloud config list --all
```

View specific configuration:
```bash
gcloud config configurations describe <NAME>
```

Delete a configuration:
```bash
gcloud config configurations delete <NAME>
```
