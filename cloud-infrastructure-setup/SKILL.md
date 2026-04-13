---
name: cloud-infrastructure-setup
description: Full lifecycle management of Google Cloud Platform infrastructure for ML training. Use when installing gcloud CLI, authenticating (user/ADC/service accounts), creating projects, linking billing, enabling APIs, configuring IAM roles for Vertex AI, managing environment variables, switching between projects, setting budget alerts, diagnosing permission/quota issues, or auditing account health.
---

<cloud-infrastructure-setup>
This skill covers setting up and managing GCP infrastructure for ML training — from installing the CLI through authentication, project creation, API enablement, IAM configuration, environment management, cost controls, and diagnostics.

**What's covered:**
- `<gcloud-setup>` — Installing gcloud, authenticating (user, ADC, service accounts), config profiles
- `<project-and-apis>` — Creating projects, linking billing, enabling required ML APIs
- `<iam-and-service-accounts>` — Service accounts, role assignments, policy management, least privilege
- `<environment-management>` — Environment variables template, multi-project configurations
- `<cost-controls>` — Budget alerts, Spot VMs, quota management
- `<diagnostics>` — Full account health checks, targeted troubleshooting
- `<common-errors>` — Authentication failures, permission denied, quota exhaustion
- `<anti-patterns>` — Mistakes that cause cost overruns or broken setups

**Scripts (subcommand-style — run without args to see all commands):**
- `scripts/gcp_auth.sh` — Login, ADC, service accounts, config profiles, whoami
- `scripts/gcp_projects.sh` — Project CRUD, billing, APIs, quotas, labels, full setup
- `scripts/gcp_iam.sh` — IAM grants/revokes, custom roles, policy export, audit
- `scripts/gcp_diagnose.sh` — Full health diagnostic, targeted checks (auth, billing, APIs, quotas, IAM)

**Scripts (one-shot utilities):**
- `scripts/setup-gcloud.sh` — Installs gcloud if missing, full setup flow
- `scripts/set-env.sh` — Environment variable template — copy to `.env` and source
- `scripts/check-permissions.sh` — Verify IAM roles, APIs, quotas, resource access

**Approach:** Write the full command with actual variable names. Let the user run it, read the output together, and decide next steps based on what happened. For simple commands (API enablement, config switching, budget creation) — use the gcloud CLI directly, no script needed.

**References:** `references/gcloud-cheat-sheet.md`, `references/iam-roles-reference.md`, `references/cost-management-guide.md`, `references/troubleshooting.md`, `references/documentation-links.md`

**No prerequisites.** This is the foundational skill — other skills depend on it.
</cloud-infrastructure-setup>

<gcloud-setup>
**Automated full setup** — creates project, links billing, enables APIs, creates service account:
```bash
./scripts/gcp_projects.sh full_setup my-ml-project XXXXXX-XXXXXX-XXXXXX
```

Or use the one-shot script (also installs gcloud if missing):
```bash
./scripts/setup-gcloud.sh my-ml-project us-central1
```

**Authentication** — three credential types:
```bash
./scripts/gcp_auth.sh login              # browser-based OAuth
./scripts/gcp_auth.sh adc                # Application Default Credentials (for SDKs)
./scripts/gcp_auth.sh whoami             # show account + project + region
```

**ADC is separate from `gcloud auth login`.** Code using the Vertex AI SDK, `google-cloud-storage`, or any client library reads ADC — not gcloud login. Always run both.

**Service accounts** for automation:
```bash
./scripts/gcp_auth.sh sa_create my-project ml-training-sa
./scripts/gcp_iam.sh sa_grant my-project ml-training-sa@my-project.iam.gserviceaccount.com roles/aiplatform.user
```

**Config profiles** to switch between projects — use `gcloud config configurations` directly:
```bash
gcloud config configurations create dev          # create new config
gcloud config set project my-ml-project-dev      # set project in it
gcloud config set compute/region us-central1     # set region
gcloud config configurations activate prod       # switch to another config
```
</gcloud-setup>

<project-and-apis>
**Project lifecycle:**
```bash
./scripts/gcp_projects.sh create my-ml-project "My ML Project"
./scripts/gcp_projects.sh billing_link my-ml-project XXXXXX-XXXXXX-XXXXXX
./scripts/gcp_projects.sh set_default my-ml-project
```

**Enable APIs** — use `gcloud services enable` directly:
```bash
# All required ML APIs at once
gcloud services enable \
  aiplatform.googleapis.com \
  compute.googleapis.com \
  storage.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com
```

Run it. The output confirms each API enabled. If you get a permissions error, the billing account may not be linked. APIs take 1–2 minutes to propagate. Verify:
```bash
gcloud services list --enabled | grep aiplatform
```

Or use the subcommand script for single APIs:
```bash
./scripts/gcp_projects.sh apis_enable my-project aiplatform.googleapis.com storage.googleapis.com
```

See `references/gcloud-cheat-sheet.md` for API groups (core, ML, container, infrastructure).
</project-and-apis>

<iam-and-service-accounts>
Training jobs should use a dedicated service account. Grant minimum required roles:

| Role | Why |
|------|-----|
| `roles/aiplatform.user` | Create and manage training jobs, endpoints, models |
| `roles/storage.admin` | Read training data, write artifacts and checkpoints |
| `roles/artifactregistry.reader` | Pull custom training containers |
| `roles/logging.logWriter` | Write training logs |
| `roles/monitoring.metricWriter` | Write training metrics |

**Grant roles via script:**
```bash
./scripts/gcp_iam.sh sa_grant my-project ml-training-sa@my-project.iam.gserviceaccount.com roles/aiplatform.user
```

**Audit and inspect:**
```bash
./scripts/gcp_iam.sh member_roles my-project user@example.com      # what roles does this user have?
./scripts/gcp_iam.sh least_privilege_check my-project               # flag overly broad roles
./scripts/gcp_iam.sh policy_export my-project backup.json           # backup IAM policy
```

See `references/iam-roles-reference.md` for full permission tables, role combinations by use case, and custom role YAML templates.
</iam-and-service-accounts>

<environment-management>
Use `scripts/set-env.sh` as a template. Copy, fill in values, source:

```bash
cp scripts/set-env.sh .env
# Edit .env — set GCP_PROJECT_ID, GCP_REGION, etc.
source .env
verify_gcp_env   # built-in validation function
```

Key variables: `GCP_PROJECT_ID`, `GCP_REGION`, `GCS_BUCKET`, `TRAINING_SERVICE_ACCOUNT`, `ARTIFACT_REGISTRY`.

**Multi-project setups** — use gcloud configurations:
```bash
gcloud config configurations create dev && gcloud config set project my-ml-project-dev && gcloud config set compute/region us-central1
gcloud config configurations activate prod       # switch back
```

Always verify the active project before expensive operations: `gcloud config get-value project`.
</environment-management>

<cost-controls>
ML training costs are dominated by GPU compute (70–90%). See `references/cost-management-guide.md` for GPU pricing tables, checkpointing code, and automated cost control.

**Budget alerts** — use `gcloud billing budgets create` directly:
```bash
gcloud billing budgets create \
  --billing-account=XXXXXX-XXXXXX-XXXXXX \
  --display-name="ML Training Budget" \
  --budget-amount=1000USD \
  --threshold-rule=percent=50 \
  --threshold-rule=percent=80 \
  --threshold-rule=percent=100
```

Run it. The output shows the budget ID. If it fails, you need billing administrator permissions. Find your billing account ID with: `gcloud billing accounts list`.

Or use the subcommand: `./scripts/gcp_projects.sh budget_create BILLING_ACCOUNT_ID "ML Budget" 1000`

**Spot VMs** — 60–70% savings, but can be preempted. Always implement checkpointing.
Spot cannot be set via gcloud CLI flags. Use YAML config (`scheduling: { strategy: SPOT }`) or the `cloud-job-orchestration` skill's `submit-training-job.py --use-spot`.

**Quotas** — GPU quotas default to 0 in most regions. Vertex AI training uses separate quotas from Compute Engine (e.g. `custom_model_training_nvidia_t4_gpus`). Request increases 2–3 business days ahead:
```bash
./scripts/gcp_projects.sh quota_check my-project us-central1
```
</cost-controls>

<diagnostics>
Use `scripts/gcp_diagnose.sh` for comprehensive health checks:

```bash
./scripts/gcp_diagnose.sh full my-project   # complete check: auth, billing, APIs, IAM, quotas, org policies
./scripts/gcp_diagnose.sh auth              # authentication and ADC only
./scripts/gcp_diagnose.sh billing my-project
./scripts/gcp_diagnose.sh apis my-project   # flags missing required APIs
./scripts/gcp_diagnose.sh quotas my-project us-central1
./scripts/gcp_diagnose.sh iam my-project    # flags overly broad roles
```

For quick permission checks, use the one-shot script:
```bash
./scripts/check-permissions.sh              # checks current user
./scripts/check-permissions.sh sa@project.iam.gserviceaccount.com
```

**Always check quotas before submitting GPU training jobs.** Vertex AI training GPU quota (`custom_model_training_nvidia_*_gpus`) is separate from Compute Engine GPU quota and defaults to 0. Run quota diagnostics first to avoid repeated `RESOURCE_EXHAUSTED` failures.

Full diagnostic workflows for specific error cases in `references/troubleshooting.md`.
</diagnostics>

<common-errors>
| Error | Cause | Fix |
|-------|-------|-----|
| `403 Forbidden` / `PERMISSION_DENIED` | Missing IAM role | `./scripts/gcp_diagnose.sh iam my-project` → grant missing roles |
| `DefaultCredentialsError` | No ADC configured | `./scripts/gcp_auth.sh adc` |
| `API has not been used` | API not enabled | `gcloud services enable aiplatform.googleapis.com` |
| `QUOTA_EXCEEDED` | GPU/CPU quota limit | `./scripts/gcp_diagnose.sh quotas my-project us-central1` |
| `Billing not enabled` | No billing linked | `./scripts/gcp_projects.sh billing_link my-project XXXXXX` |
| `invalid_grant: Token expired` | Stale credentials | `./scripts/gcp_auth.sh login` + `./scripts/gcp_auth.sh adc` |

When debugging, start with: `./scripts/gcp_diagnose.sh full my-project`
</common-errors>

<anti-patterns>
- **Skipping ADC** — `gcloud auth login` alone won't work for Python SDK code. Always also run `gcp_auth.sh adc`.
- **Over-privileged service accounts** — granting `roles/owner` instead of specific roles. Run `gcp_iam.sh least_privilege_check`.
- **Hardcoded project IDs** — use `gcloud config get-value project` or env vars.
- **No budget alerts** — GPU jobs left running overnight can cost hundreds. Always set alerts.
- **Requesting GPU quota last minute** — increases take 2–3 business days.
- **Region mismatch** — data in `us-central1` but training in `europe-west4` incurs egress charges.
- **Service account key files committed to git** — use Workload Identity Federation for CI/CD instead.
</anti-patterns>

<cloud-infrastructure-setup-scripts>
**Subcommand scripts** (run without args to see all commands):

| Script | Commands | Purpose |
|---|---|---|
| `gcp_auth.sh` | login, adc, whoami, sa_create, profile_*, ... | Authentication, ADC, service accounts, config profiles |
| `gcp_projects.sh` | create, billing_link, apis_enable, full_setup, ... | Project lifecycle, billing, APIs, quotas, labels |
| `gcp_iam.sh` | grant, revoke, sa_grant, least_privilege_check, ... | IAM roles, policy management, audit |
| `gcp_diagnose.sh` | full, auth, billing, apis, quotas, iam, ... | Account health diagnostics |

**One-shot utility scripts:**

| Script | Purpose |
|---|---|
| `setup-gcloud.sh` | Install gcloud, auth, project config, APIs, SA, bucket |
| `check-permissions.sh` | Verify IAM roles, APIs, quotas, resource access |
| `set-env.sh` | Environment variable template — copy to `.env` and source |

For config switching, API enablement, and budget alerts — use `gcloud` directly. Commands in `references/gcloud-cheat-sheet.md`.
</cloud-infrastructure-setup-scripts>

<cloud-infrastructure-setup-reference>
| File | Contents |
|---|---|
| `references/gcloud-cheat-sheet.md` | Quick command reference: auth, projects, IAM, GCS, Vertex AI, quotas, API groups, budget alerts, config switching |
| `references/iam-roles-reference.md` | Predefined roles, permissions per operation, role combinations by use case, custom role YAML |
| `references/cost-management-guide.md` | GPU pricing, Spot VM implementation, checkpointing code, budget automation, GCS lifecycle policies |
| `references/troubleshooting.md` | Full diagnostic workflows for auth, API, storage, Vertex AI, network, and billing issues |
| `references/documentation-links.md` | Official GCP docs, SDK references, community resources |
</cloud-infrastructure-setup-reference>

<examples>
**Scenario:** Set up a new GCP project for ML training from scratch.

**Step 1 — Create project with billing and APIs:**
```bash
./scripts/gcp_projects.sh full_setup my-ml-project XXXXXX-XXXXXX-XXXXXX
```
Read the output — it creates project, links billing, enables APIs, creates SA. If any step fails, the error tells you what's missing.

**Step 2 — Authenticate:**
```bash
./scripts/gcp_auth.sh login
./scripts/gcp_auth.sh adc
gcloud config set compute/region us-central1
```

**Step 3 — Service account roles:**
```bash
./scripts/gcp_auth.sh sa_create my-ml-project ml-training-sa
./scripts/gcp_iam.sh sa_grant my-ml-project \
  ml-training-sa@my-ml-project.iam.gserviceaccount.com roles/aiplatform.user
./scripts/gcp_iam.sh sa_grant my-ml-project \
  ml-training-sa@my-ml-project.iam.gserviceaccount.com roles/storage.admin
```

**Step 4 — Diagnose:** `./scripts/gcp_diagnose.sh full my-ml-project` — each check shows ✓ or ✗.

**Step 5 — Budget alert:**
```bash
gcloud billing budgets create --billing-account=XXXXXX-XXXXXX-XXXXXX \
  --display-name="ML Budget" --budget-amount=500USD \
  --threshold-rule=percent=50 --threshold-rule=percent=80 --threshold-rule=percent=100
```

**Common mistake — ADC not set up:**
```python
from google.cloud import aiplatform
aiplatform.init(project="my-ml-project", location="us-central1")
# Raises DefaultCredentialsError — forgot to run: ./scripts/gcp_auth.sh adc
```
</examples>
