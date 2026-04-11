#!/bin/bash
# Purpose: Full Google Cloud account health diagnostic — auth, billing, APIs, quotas, IAM, and org policies.
# Input:   COMMAND (arg 1) and optional project_id.
# Output:  Structured health report to stderr; warnings highlighted.
#
# Usage:
#   ./gcp_diagnose.sh full <project_id>            # complete account health check (recommended starting point)
#   ./gcp_diagnose.sh auth                         # check authentication and ADC status
#   ./gcp_diagnose.sh config                       # show gcloud config (account, project, region, zone)
#   ./gcp_diagnose.sh billing <project_id>         # check billing linkage and account status
#   ./gcp_diagnose.sh apis <project_id>            # list enabled APIs and flag missing Gemma 4 ones
#   ./gcp_diagnose.sh quotas <project_id> <region> # show GPU and Vertex AI quotas for a region
#   ./gcp_diagnose.sh iam <project_id>             # summarize IAM policy and flag broad roles
#   ./gcp_diagnose.sh org_policies <project_id>    # list active org policy constraints
#   ./gcp_diagnose.sh service_account <project>    # list service accounts and their key ages
#   ./gcp_diagnose.sh sdk_info                     # print SDK version, Python path, log dir
#   ./gcp_diagnose.sh regions <project_id>         # list available regions
#   ./gcp_diagnose.sh zones <project_id> <region>  # list zones in a specific region

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# APIs required for Gemma 4 fine-tuning
REQUIRED_APIS=(
  aiplatform.googleapis.com
  storage.googleapis.com
  compute.googleapis.com
  cloudbuild.googleapis.com
  artifactregistry.googleapis.com
  iam.googleapis.com
  cloudresourcemanager.googleapis.com
)

# Roles considered too broad for production workloads
BROAD_ROLES=("roles/owner" "roles/editor")

# ─── Helpers ──────────────────────────────────────────────────────────────────

section() { echo ""; echo "══════════════════════ $1 ══════════════════════" >&2; }
ok()      { echo "  ✓ $1" >&2; }
warn()    { echo "  ⚠ $1" >&2; }
info()    { echo "  · $1" >&2; }

check_auth() {
  section "Authentication"
  ACTIVE_ACCOUNT="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null)"
  if [ -z "$ACTIVE_ACCOUNT" ]; then
    warn "No active account. Run: ./gcp_auth.sh login"
  else
    ok "Authenticated as: $ACTIVE_ACCOUNT"
  fi

  section "Application Default Credentials (ADC)"
  if gcloud auth application-default print-access-token --quiet >/dev/null 2>&1; then
    ok "ADC is configured and valid."
  else
    warn "ADC not configured. Run: ./gcp_auth.sh adc"
  fi
}

check_config() {
  section "Active Configuration"
  PROJECT="$(gcloud config get-value project 2>/dev/null)"
  REGION="$(gcloud config get-value compute/region 2>/dev/null)"
  ZONE="$(gcloud config get-value compute/zone 2>/dev/null)"
  PROFILE="$(gcloud config configurations list --filter=is_active=true --format='value(name)' 2>/dev/null)"
  info "Profile : ${PROFILE:-default}"
  info "Project : ${PROJECT:-(not set)}"
  info "Region  : ${REGION:-(not set)}"
  info "Zone    : ${ZONE:-(not set)}"
  [ -z "$PROJECT" ] && warn "No default project set. Run: ./gcp_projects.sh set_default <project_id>"
  [ -z "$REGION" ]  && warn "No default region set. Run: ./gcp_auth.sh set_region <region>"
}

check_billing() {
  local PROJECT="$1"
  section "Billing for $PROJECT"
  RESULT="$(gcloud beta billing projects describe "$PROJECT" --format='yaml(billingEnabled,billingAccountName)' 2>&1)"
  if echo "$RESULT" | grep -q "billingEnabled: true"; then
    ACCT="$(echo "$RESULT" | grep billingAccountName | awk '{print $2}')"
    ok "Billing enabled. Account: $ACCT"
  else
    warn "Billing is NOT enabled on $PROJECT."
    warn "Run: ./gcp_projects.sh billing_link $PROJECT <billing_account_id>"
  fi
}

check_apis() {
  local PROJECT="$1"
  section "API Enablement for $PROJECT"
  ENABLED="$(gcloud services list --enabled --project="$PROJECT" --format='value(config.name)' 2>/dev/null)"
  for API in "${REQUIRED_APIS[@]}"; do
    if echo "$ENABLED" | grep -qF "$API"; then
      ok "$API"
    else
      warn "MISSING: $API — run: ./gcp_projects.sh apis_enable $PROJECT $API"
    fi
  done
}

check_quotas() {
  local PROJECT="$1"
  local REGION="$2"
  section "GPU & Compute Quotas in $REGION ($PROJECT)"
  gcloud compute regions describe "$REGION" \
    --project="$PROJECT" \
    --format="yaml(quotas)" 2>/dev/null \
    | grep -A2 -i "gpu\|accelerator\|nvidia" \
    || warn "No GPU quotas found in $REGION. Request an increase via Console > IAM & Admin > Quotas."

  section "Vertex AI Quotas"
  gcloud services quota list \
    --service=aiplatform.googleapis.com \
    --consumer="project:$PROJECT" 2>/dev/null \
    | head -40 \
    || warn "Could not retrieve Vertex AI quotas. Ensure aiplatform.googleapis.com is enabled."
}

check_iam() {
  local PROJECT="$1"
  section "IAM Broad Role Audit for $PROJECT"
  FOUND=0
  for ROLE in "${BROAD_ROLES[@]}"; do
    MEMBERS="$(gcloud projects get-iam-policy "$PROJECT" \
      --flatten="bindings[].members" \
      --filter="bindings.role=$ROLE" \
      --format="value(bindings.members)" 2>/dev/null || true)"
    if [ -n "$MEMBERS" ]; then
      warn "Broad role '$ROLE' assigned to:"
      while IFS= read -r M; do warn "  - $M"; done <<< "$MEMBERS"
      FOUND=1
    fi
  done
  [ "$FOUND" -eq 0 ] && ok "No overly broad roles detected."

  section "Service Account Count"
  COUNT="$(gcloud iam service-accounts list --project="$PROJECT" --format='value(email)' | wc -l)"
  info "$COUNT service account(s) in $PROJECT"
}

check_org_policies() {
  local PROJECT="$1"
  section "Org Policies on $PROJECT"
  POLICIES="$(gcloud resource-manager org-policies list --project="$PROJECT" --format='value(constraint)' 2>/dev/null || true)"
  if [ -z "$POLICIES" ]; then
    ok "No org policies enforced on this project."
  else
    while IFS= read -r POLICY; do
      info "$POLICY"
    done <<< "$POLICIES"
    BLOCKING_COUNT="$(echo "$POLICIES" | grep -c 'resourceLocations\|restrictVpcPeering\|disableSerialPortAccess\|iam.disable' || true)"
    [ "$BLOCKING_COUNT" -gt 0 ] && warn "$BLOCKING_COUNT potentially blocking constraint(s) detected. Review with: ./gcp_projects.sh org_policies $PROJECT"
  fi
}

check_service_accounts() {
  local PROJECT="$1"
  section "Service Accounts in $PROJECT"
  gcloud iam service-accounts list \
    --project="$PROJECT" \
    --format="table(email:label=EMAIL,displayName:label=NAME,disabled:label=DISABLED)" 2>/dev/null \
    || warn "Could not list service accounts. Check IAM permissions."
}

# ─── Commands ─────────────────────────────────────────────────────────────────

if [ $# -lt 1 ]; then
  grep '^#   \./gcp_diagnose' "${BASH_SOURCE[0]}" | sed 's/^#   /  /' >&2
  exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in

  # 1. Full: Run every diagnostic check for a project. The recommended starting point.
  full)
    if [ $# -ne 1 ]; then echo "Usage: full <project_id>" >&2; exit 1; fi
    PROJECT="$1"
    REGION="$(gcloud config get-value compute/region 2>/dev/null || true)"
    echo "" >&2
    echo "╔═══════════════════════════════════════════╗" >&2
    echo "║      GCP Account Health Diagnostic        ║" >&2
    echo "╚═══════════════════════════════════════════╝" >&2
    check_auth
    check_config
    check_billing "$PROJECT"
    check_apis "$PROJECT"
    check_iam "$PROJECT"
    check_org_policies "$PROJECT"
    check_service_accounts "$PROJECT"
    if [ -n "$REGION" ]; then
      check_quotas "$PROJECT" "$REGION"
    else
      section "Quotas"
      warn "No default region set — skipping quota check."
      warn "Run: ./gcp_auth.sh set_region <region>  then re-run: ./gcp_diagnose.sh full $PROJECT"
    fi
    echo "" >&2
    echo "═══════════════════════ Done ═══════════════════════" >&2
    ;;

  # 2. Auth: Check authentication and ADC only.
  auth)
    check_auth
    ;;

  # 3. Config: Show the active gcloud configuration.
  config)
    check_config
    ;;

  # 4. Billing: Check billing linkage for a project.
  billing)
    if [ $# -ne 1 ]; then echo "Usage: billing <project_id>" >&2; exit 1; fi
    check_billing "$1"
    ;;

  # 5. APIs: Check which required Gemma 4 APIs are enabled.
  apis)
    if [ $# -ne 1 ]; then echo "Usage: apis <project_id>" >&2; exit 1; fi
    check_apis "$1"
    ;;

  # 6. Quotas: Check GPU and Vertex AI quotas for a specific region.
  quotas)
    if [ $# -ne 2 ]; then echo "Usage: quotas <project_id> <region>" >&2; exit 1; fi
    check_quotas "$1" "$2"
    ;;

  # 7. IAM: Audit IAM policy for broad roles.
  iam)
    if [ $# -ne 1 ]; then echo "Usage: iam <project_id>" >&2; exit 1; fi
    check_iam "$1"
    ;;

  # 8. Org Policies: List active org policy constraints.
  org_policies)
    if [ $# -ne 1 ]; then echo "Usage: org_policies <project_id>" >&2; exit 1; fi
    check_org_policies "$1"
    ;;

  # 9. Service Account: List service accounts and key metadata.
  service_account)
    if [ $# -ne 1 ]; then echo "Usage: service_account <project_id>" >&2; exit 1; fi
    check_service_accounts "$1"
    section "Service Account Keys"
    gcloud iam service-accounts list \
      --project="$1" \
      --format="value(email)" 2>/dev/null | while IFS= read -r SA_EMAIL; do
        echo "" >&2
        info "Keys for $SA_EMAIL:"
        gcloud iam service-accounts keys list \
          --iam-account="$SA_EMAIL" \
          --project="$1" \
          --format="table(name:label=KEY_ID,validAfterTime:label=CREATED,keyType:label=TYPE)" 2>/dev/null \
          || warn "  Could not list keys."
    done
    ;;

  # 10. SDK Info: Print gcloud SDK version, Python path, and log directory.
  sdk_info)
    section "gcloud SDK Information"
    gcloud info --format="yaml(installation,config,logs)"
    ;;

  # 11. Regions: List all compute regions available for this project.
  regions)
    if [ $# -ne 1 ]; then echo "Usage: regions <project_id>" >&2; exit 1; fi
    gcloud compute regions list \
      --project="$1" \
      --format="table(name:label=REGION,status:label=STATUS)"
    ;;

  # 12. Zones: List compute zones in a specific region.
  zones)
    if [ $# -ne 2 ]; then echo "Usage: zones <project_id> <region>" >&2; exit 1; fi
    gcloud compute zones list \
      --project="$1" \
      --filter="region:$2" \
      --format="table(name:label=ZONE,status:label=STATUS)"
    ;;

  *)
    echo "Unknown command: $COMMAND. Run without args to see all commands." >&2
    exit 1
    ;;
esac
