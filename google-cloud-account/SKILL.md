---
name: google-cloud-account
description: Full lifecycle management of a Google Cloud Platform account via gcloud CLI. Covers authentication (user login, ADC, service accounts), project creation and configuration, billing setup and linkage, IAM roles and permissions, API/service enablement, quota inspection, budget alerts, and account diagnostics. Use this skill when the user asks about GCP account setup, authentication, project management, billing, IAM permissions, API enablement, quotas, budgets, or any gcloud configuration task.
---

<google-cloud-account>
Complete GCP account management from first authentication to production readiness. This skill teaches how to set up and maintain a Google Cloud account for machine learning workloads (specifically Gemma 4 fine-tuning).

**Core topics covered:**
- **Installation** — Install Google Cloud SDK (gcloud CLI)
- **Authentication** — user login, Application Default Credentials (ADC), service accounts, config profiles
- **Projects** — creation, billing linkage, API enablement
- **IAM & Permissions** — roles, policy bindings, service account management
- **Quotas & Billing** — GPU quota checks, budget alerts
- **Diagnostics** — health checks and troubleshooting

**Scripts included:** Four focused bash scripts in `scripts/` directory handle all operations:
- `gcp_auth.sh` — Authentication and config profiles
- `gcp_projects.sh` — Project lifecycle, billing, APIs
- `gcp_iam.sh` — IAM roles and policy management
- `gcp_diagnose.sh` — Health checks and diagnostics

Run any script without arguments to see available commands.

**Reference files:** See `reference.md` for detailed API lists, role permissions, quota information, and troubleshooting guides.

</google-cloud-account>

<installation>
Install the Google Cloud SDK (gcloud CLI) before any other operations.

**Installation:** Follow the official guide at https://cloud.google.com/sdk/docs/install

**Verify:**
```bash
gcloud version
```

</installation>

<authentication>
Authentication is the entry point for all GCP operations. Three credential types cover different use cases.

### User Account (Interactive)
```bash
./scripts/gcp_auth.sh login              # Browser-based OAuth
./scripts/gcp_auth.sh whoami             # Show current identity
./scripts/gcp_auth.sh list               # List all credentialed accounts
```

### Application Default Credentials (ADC)
Required for client libraries (Python `google-cloud-*`, Terraform).
```bash
./scripts/gcp_auth.sh adc                # Configure ADC
./scripts/gcp_auth.sh adc_token          # Verify ADC is working
```

### Service Accounts
For automation and CI/CD. Never commit key files.
```bash
./scripts/gcp_auth.sh sa_create <name>   # Create service account
./scripts/gcp_auth.sh sa_key <email>     # Generate key file
./scripts/gcp_auth.sh sa_activate <key>  # Activate from key file
```

### Config Profiles
Switch between accounts/projects instantly:
```bash
./scripts/gcp_auth.sh profile_create <name>    # Create new profile
./scripts/gcp_auth.sh profile_activate <name>  # Switch profiles
./scripts/gcp_auth.sh profile_list             # List all profiles
./scripts/gcp_auth.sh set_region <region>      # Set default region
```

</authentication>

<project-management>
Every GCP resource lives in a project — the unit of billing, IAM, and API access.

### Project Lifecycle
```bash
./scripts/gcp_projects.sh create <id> <name>   # Create new project
./scripts/gcp_projects.sh list                 # List accessible projects
./scripts/gcp_projects.sh describe <id>        # Show project details
./scripts/gcp_projects.sh delete <id>          # Soft-delete (30-day recovery)
```

### Billing
Projects require an active billing account for paid APIs (Vertex AI, GPUs).
```bash
./scripts/gcp_projects.sh billing_accounts     # List billing accounts
./scripts/gcp_projects.sh billing_link <project> <account_id>
./scripts/gcp_projects.sh billing_status <project>
```

### Budget Alerts
Prevent bill shock with automated alerts:
```bash
./scripts/gcp_projects.sh budget_create <account_id> <amount>
```

### API Enablement
Required APIs for Gemma 4 fine-tuning:
```bash
./scripts/gcp_projects.sh apis_enable <project>
# Enables: aiplatform, storage, compute, cloudbuild, artifactregistry
```

</project-management>

<iam-and-permissions>
IAM controls **who** can do **what** on **which resource**. Follow least-privilege.

### Project-Level Policy
```bash
./scripts/gcp_iam.sh policy <project>              # View full policy
./scripts/gcp_iam.sh grant <project> <member> <role>   # Add binding
./scripts/gcp_iam.sh revoke <project> <member> <role>  # Remove binding
```

### Service Account IAM
```bash
./scripts/gcp_iam.sh sa_grant <project> <sa_email> <role>
./scripts/gcp_iam.sh sa_allow_impersonate <sa_email> <user_email>
```

### Common Roles for Gemma 4
| Role | Purpose |
|------|---------|
| `roles/aiplatform.user` | Use Vertex AI endpoints |
| `roles/aiplatform.admin` | Full Vertex AI control |
| `roles/storage.objectAdmin` | Read/write GCS buckets |
| `roles/compute.instanceAdmin.v1` | Manage GPU VMs |
| `roles/billing.viewer` | Monitor costs |

</iam-and-permissions>

<quotas-and-limits>
GPU and TPU quotas gate whether workloads can run. Check early.

### Inspect Quotas
```bash
./scripts/gcp_projects.sh quota_check <project> <region>
# Shows CPU, GPU, and other regional quotas
```

### Requesting Increases
GPU quota increases (A100, H100) require Console submission and take 1–3 business days. Request in advance.

</quotas-and-limits>

<diagnostics>
Health checks and troubleshooting for the entire account.

### Full Status Check
```bash
./scripts/gcp_diagnose.sh full <project>
```

### Targeted Checks
```bash
./scripts/gcp_diagnose.sh auth           # Authentication status
./scripts/gcp_diagnose.sh billing <project>   # Billing status
./scripts/gcp_diagnose.sh apis <project>      # Enabled APIs
./scripts/gcp_diagnose.sh quotas <project> <region>  # Quota status
./scripts/gcp_diagnose.sh iam <project>       # IAM policy summary
```

</diagnostics>

<google-cloud-account-scripts>
All scripts live in `scripts/` and are self-documenting. Run without arguments to see commands.

| Script | Purpose |
|--------|---------|
| `gcp_auth.sh` | Authentication, ADC, service accounts, config profiles |
| `gcp_projects.sh` | Projects, billing, APIs, quotas, budgets |
| `gcp_iam.sh` | IAM roles, policy bindings, service account permissions |
| `gcp_diagnose.sh` | Health checks, diagnostics, troubleshooting |

All scripts use `gcloud` CLI and require it to be installed (see Installation topic) and authenticated.

</google-cloud-account-scripts>

<google-cloud-account-reference>
See `reference.md` for detailed information:
- Required APIs for fine-tuning
- Complete role permission tables
- Quota types and limits
- Common errors and solutions
- gcloud command reference

</google-cloud-account-reference>

<examples>

### Complete New Account Setup
```bash
# 1. Install Google Cloud SDK (see Installation topic)
# macOS: brew install --cask google-cloud-sdk
# Linux: sudo apt-get install google-cloud-sdk

# 2. Verify installation
gcloud version

# 3. Authenticate
./scripts/gcp_auth.sh login
./scripts/gcp_auth.sh whoami

# 2. Create project with billing
./scripts/gcp_projects.sh create my-gemma-project "Gemma Fine Tuning"
./scripts/gcp_projects.sh billing_accounts
./scripts/gcp_projects.sh billing_link my-gemma-project 0X0X0X-0X0X0X-0X0X0X

# 3. Enable required APIs
./scripts/gcp_projects.sh apis_enable my-gemma-project

# 4. Verify setup
./scripts/gcp_diagnose.sh full my-gemma-project
```

### Service Account for CI/CD
```bash
./scripts/gcp_auth.sh sa_create gemma-ci
./scripts/gcp_iam.sh sa_grant my-gemma-project \
  gemma-ci@my-gemma-project.iam.gserviceaccount.com \
  roles/aiplatform.admin
./scripts/gcp_auth.sh sa_key \
  gemma-ci@my-gemma-project.iam.gserviceaccount.com
```

### Troubleshooting: "Billing not enabled"
```bash
./scripts/gcp_projects.sh billing_status my-project
./scripts/gcp_projects.sh billing_link my-project <BILLING_ACCOUNT_ID>
./scripts/gcp_diagnose.sh billing my-project
```

### Switching Between Projects
```bash
./scripts/gcp_auth.sh profile_create dev
./scripts/gcp_auth.sh profile_create prod
./scripts/gcp_auth.sh profile_activate dev
./scripts/gcp_auth.sh set_region us-central1
gcloud config set project my-dev-project
# Switch back: ./scripts/gcp_auth.sh profile_activate prod
```

</examples>

<common-mistakes>

- **gcloud not installed** — Install Google Cloud SDK first (see Installation topic).
- **Billing not linked** — Most API calls fail without billing. Run `billing_status` first.
- **Wrong region quotas** — Check `quota_check` in your target region.
- **ADC not configured** — Client libraries need ADC separately from user login.
- **Service account key exposure** — Never commit key files.
- **Project ID vs name** — Use globally unique project IDs, not display names.

</common-mistakes>
