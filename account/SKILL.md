---
name: google-cloud-account
description: Full lifecycle management of a Google Cloud account via gcloud CLI. Covers authentication (user & service accounts, ADC), project creation and configuration, billing setup and troubleshooting, IAM roles and policy bindings, API/service enablement, quota inspection, organization policies, budget alerts, resource tagging, config profiles, and diagnostics. Use this skill whenever the user asks about GCP account setup, authentication, project management, billing linkage, IAM permissions, API enablement, quotas, budgets, org policies, or any gcloud configuration task.
---

# Google Cloud Account Management

This skill is the authoritative reference for managing a Google Cloud account through an agent. It covers every layer of account control — from first authentication to ongoing governance — so an agent can confidently set up, inspect, repair, and maintain a GCP environment without manual console access.

**Operational tool:** `scripts/gcp_account_manager.sh` — 20 callable operations covering every action in this skill. Run it without arguments to see the full menu. Always prefer the script for repeatable actions; use raw `gcloud` only for one-offs or debugging.

**Topics covered:**
1. [Authentication](#1-authentication) — login, ADC, service accounts, config profiles
2. [Project Management](#2-project-management) — create, list, describe, delete, set defaults
3. [Billing](#3-billing) — accounts, linking, status, budget alerts
4. [IAM & Permissions](#4-iam--permissions) — policy bindings, service accounts, roles, audit
5. [API & Service Enablement](#5-api--service-enablement) — enable, disable, list
6. [Quotas & Limits](#6-quotas--limits) — inspect, request increases
7. [Organization Policies](#7-organization-policies) — list, describe, enforce constraints
8. [Config & Diagnostics](#8-config--diagnostics) — profiles, regions/zones, full status check

---

## 1. Authentication

Authentication is the entry point for all other operations. There are three credential types; use the right one for the context.

### User Account (interactive)
```bash
gcloud auth login                          # browser-based OAuth; use for human operators
gcloud auth list                           # show all credentialed accounts
gcloud auth revoke <email>                 # remove credentials for an account
```

### Application Default Credentials (ADC)
ADC is used by client libraries (Python `google-cloud-*`, Terraform, etc.). It must be configured separately from user login.
```bash
gcloud auth application-default login
gcloud auth application-default set-quota-project <PROJECT_ID>
gcloud auth application-default print-access-token   # verify ADC is working
```

### Service Account
Use service accounts for automation and CI/CD. Never embed key files in source code.
```bash
# Create a service account
gcloud iam service-accounts create <SA_NAME> --project=<PROJECT_ID> \
  --display-name="<Display Name>"

# Activate a service account key locally
gcloud auth activate-service-account --key-file=<KEY_FILE>.json

# Generate a key file (use Workload Identity Federation instead when possible)
gcloud iam service-accounts keys create key.json \
  --iam-account=<SA_EMAIL>
```

### Config Profiles
Named configurations let you switch between accounts/projects instantly — essential for multi-project work.
```bash
gcloud config configurations create <NAME>
gcloud config configurations activate <NAME>
gcloud config configurations list
gcloud config set account <EMAIL>
gcloud config set project <PROJECT_ID>
gcloud config set compute/region <REGION>
gcloud config set compute/zone <ZONE>
```

---

## 2. Project Management

Every resource in GCP lives inside a project. Projects are the primary unit of billing, IAM, and API access control.

```bash
gcloud projects list                                 # all accessible projects
gcloud projects create <PROJECT_ID> \
  --name="<Display Name>"                            # create; ID must be globally unique
gcloud projects describe <PROJECT_ID>                # status, labels, parent org/folder
gcloud config set project <PROJECT_ID>              # set default; avoids --project flag repetition
gcloud projects delete <PROJECT_ID>                  # soft-delete (30-day recovery window)
gcloud projects undelete <PROJECT_ID>               # recover within 30 days
```

**Useful flags:**
- `--folder=<FOLDER_ID>` — place project inside an org folder
- `--organization=<ORG_ID>` — attach project to an org directly
- `--labels=env=prod,team=ml` — tag projects for cost attribution

---

## 3. Billing

A project without an active billing account cannot use paid APIs (including Vertex AI and GPU quota).

### Inspect billing
```bash
gcloud beta billing accounts list                          # list all billing accounts you can see
gcloud beta billing projects describe <PROJECT_ID>         # check if billing is enabled + which account
```

### Link / change billing
```bash
gcloud beta billing projects link <PROJECT_ID> \
  --billing-account=<BILLING_ACCOUNT_ID>                   # format: XXXXXX-XXXXXX-XXXXXX
```

### Budget alerts (prevent bill shock)
Budget alerts require the Billing API enabled on the project and the `roles/billing.admin` role.
```bash
gcloud billing budgets create \
  --billing-account=<BILLING_ACCOUNT_ID> \
  --display-name="<Budget Name>" \
  --budget-amount=<AMOUNT>USD \
  --threshold-rule=percent=0.5 \
  --threshold-rule=percent=0.9 \
  --threshold-rule=percent=1.0

gcloud billing budgets list --billing-account=<BILLING_ACCOUNT_ID>
```

**Common billing errors:**
- `"Billing account not found"` → wrong account ID format; use `gcloud beta billing accounts list` to confirm the exact ID.
- `"Project has no billing account"` → run the `link` command above.
- Services suspend after non-payment → update payment method in the Console Billing UI, then re-link.

---

## 4. IAM & Permissions

IAM controls **who** can do **what** on **which resource**. Always follow least-privilege.

### View and edit project-level policy
```bash
gcloud projects get-iam-policy <PROJECT_ID>                # dump full policy as YAML

gcloud projects add-iam-policy-binding <PROJECT_ID> \
  --member="user:<EMAIL>" \
  --role="roles/<ROLE>"                                    # e.g. roles/viewer, roles/editor

gcloud projects remove-iam-policy-binding <PROJECT_ID> \
  --member="user:<EMAIL>" \
  --role="roles/<ROLE>"
```

### Service account IAM
```bash
# Grant a role to a service account on a project
gcloud projects add-iam-policy-binding <PROJECT_ID> \
  --member="serviceAccount:<SA_EMAIL>" \
  --role="roles/<ROLE>"

# Allow a user to impersonate a service account
gcloud iam service-accounts add-iam-policy-binding <SA_EMAIL> \
  --member="user:<USER_EMAIL>" \
  --role="roles/iam.serviceAccountTokenCreator"
```

### Inspect roles
```bash
gcloud iam roles list --project=<PROJECT_ID>              # custom roles in project
gcloud iam roles describe roles/<ROLE>                    # built-in role permissions
```

**Common roles for Gemma 4 deployment:**

| Role | Purpose |
|------|---------|
| `roles/aiplatform.user` | Use Vertex AI endpoints |
| `roles/aiplatform.admin` | Full Vertex AI control |
| `roles/storage.objectAdmin` | Read/write model checkpoints in GCS |
| `roles/compute.instanceAdmin.v1` | Manage GPU VMs |
| `roles/billing.viewer` | Monitor costs without changing billing |

---

## 5. API & Service Enablement

APIs must be explicitly enabled per project before they can be called.

```bash
gcloud services list --enabled --project=<PROJECT_ID>     # what's currently on
gcloud services list --available --project=<PROJECT_ID>   # all available APIs (long list)

gcloud services enable <SERVICE> --project=<PROJECT_ID>   # turn on one API
gcloud services disable <SERVICE> --project=<PROJECT_ID> --force  # turn off (destroys resources)
```

**APIs required for Gemma 4 fine-tuning:**
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

## 6. Quotas & Limits

GPU and TPU regional quotas gate whether workloads can actually run. Check quotas early.

```bash
# Compute Engine regional quotas (includes GPUs)
gcloud compute regions describe <REGION> \
  --project=<PROJECT_ID> \
  --format="yaml(quotas)"

# Filter for GPU quotas specifically
gcloud compute regions describe <REGION> \
  --project=<PROJECT_ID> \
  --format="yaml(quotas)" | grep -i gpu

# Vertex AI / general service quotas
gcloud services quota list \
  --service=aiplatform.googleapis.com \
  --consumer=project:<PROJECT_ID>
```

**Requesting an increase:** Quota increases must be submitted through the Console (`IAM & Admin > Quotas`) or via the `gcloud beta quotas` API. Approvals for GPU quotas (A100, H100) can take 1–3 business days — request in advance.

---

## 7. Organization Policies

Org policies enforce guardrails across all projects in an organization. Relevant when deploying in an enterprise GCP org.

```bash
gcloud resource-manager org-policies list \
  --project=<PROJECT_ID>                                   # policies applied to this project

gcloud resource-manager org-policies describe \
  <CONSTRAINT> --project=<PROJECT_ID>                      # e.g. constraints/compute.disableSerialPortAccess

gcloud resource-manager org-policies allow \
  <CONSTRAINT> <VALUE> --project=<PROJECT_ID>             # override a list constraint

gcloud resource-manager org-policies reset \
  <CONSTRAINT> --project=<PROJECT_ID>                      # revert to inherited policy
```

**Common constraints that block Gemma 4 deployments:**
- `constraints/compute.restrictCloudVMExternalIPs` — blocks external IPs on VMs
- `constraints/gcp.resourceLocations` — limits which regions resources can be created in
- `constraints/iam.disableServiceAccountCreation` — blocks creating service accounts

If a deployment fails with a policy violation, run `org-policies list` on the project first.

---

## 8. Config & Diagnostics

### Full account status (one command)
```bash
./scripts/gcp_account_manager.sh full_account_status
```
This reports: active auth, current config, project list, and billing status in one pass.

### Targeted diagnostics
```bash
gcloud config list                                         # all current configuration values
gcloud info                                               # SDK version, Python path, log location
gcloud auth list                                          # all credentialed accounts + active one
gcloud projects list --format="table(projectId,name,lifecycleState)"
```

### Compute infrastructure
```bash
gcloud compute regions list --project=<PROJECT_ID>        # all available regions
gcloud compute zones list --project=<PROJECT_ID>          # all zones (filter with --filter)
gcloud compute zones list \
  --filter="region:<REGION>" \
  --project=<PROJECT_ID>
```

### Debug tips
- Append `--verbosity=debug` to any `gcloud` command for detailed HTTP request/response logs.
- Append `--log-http` to log all HTTP traffic (useful for API call debugging).
- Use `--format=json` in scripts for reliable machine-parseable output.
- Use `--quiet` (`-q`) to suppress interactive prompts in automation.

---

## Supporting Scripts

All scripts live in `account/scripts/`. Run any script without arguments to see its full command list.

| Script | Domain | Key Commands |
|--------|--------|-------------|
| `gcp_auth.sh` | Authentication & config profiles | `login`, `adc`, `whoami`, `sa_create`, `sa_key_create`, `profile_create`, `profile_activate`, `impersonate`, `set_region` |
| `gcp_projects.sh` | Project lifecycle & billing | `create`, `billing_link`, `billing_accounts`, `budget_create`, `apis_enable`, `quota_check`, `full_setup`, `org_policies` |
| `gcp_iam.sh` | IAM roles & policy management | `grant`, `revoke`, `member_roles`, `custom_role_create`, `sa_grant`, `sa_allow_impersonate`, `policy_export`, `least_privilege_check` |
| `gcp_diagnose.sh` | Health checks & diagnostics | `full`, `auth`, `billing`, `apis`, `quotas`, `iam`, `org_policies`, `service_account`, `sdk_info` |

**Quick start for a new account:**
```bash
./gcp_auth.sh login                                         # authenticate
./gcp_auth.sh whoami                                        # confirm identity
./gcp_projects.sh full_setup <project_id> <billing_id>      # create + link billing + enable APIs
./gcp_diagnose.sh full <project_id>                         # verify everything is healthy
```

**Legacy consolidated script:** `../scripts/gcp_account_manager.sh` — 20 operations as a single file, kept for backwards compatibility.
