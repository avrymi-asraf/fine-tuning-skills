#!/bin/bash
# Purpose: Manage Google Cloud project lifecycle — create, configure, link billing, and clean up.
# Input:   COMMAND (arg 1) and required arguments.
# Output:  Project state, billing linkage, API enablement, labels, and audit info.
#
# Usage:
#   ./gcp_projects.sh list                                         # list all accessible projects
#   ./gcp_projects.sh create <project_id> [display_name]          # create a new project
#   ./gcp_projects.sh describe <project_id>                       # show project metadata & status
#   ./gcp_projects.sh set_default <project_id>                    # set default project in config
#   ./gcp_projects.sh delete <project_id>                         # soft-delete (30-day recovery)
#   ./gcp_projects.sh restore <project_id>                        # restore a soft-deleted project
#   ./gcp_projects.sh billing_status <project_id>                 # show billing linkage
#   ./gcp_projects.sh billing_link <project_id> <billing_id>      # link project to billing account
#   ./gcp_projects.sh billing_unlink <project_id>                 # disable billing on a project
#   ./gcp_projects.sh billing_accounts                            # list all accessible billing accounts
#   ./gcp_projects.sh budget_create <billing_id> <name> <amount>  # create a budget alert
#   ./gcp_projects.sh budget_list <billing_id>                    # list all budgets for an account
#   ./gcp_projects.sh label_set <project_id> <key=value,...>      # add/update project labels
#   ./gcp_projects.sh label_list <project_id>                     # show project labels
#   ./gcp_projects.sh apis_enable <project_id> <svc1> [svc2...]   # enable one or more APIs
#   ./gcp_projects.sh apis_disable <project_id> <service>         # disable an API
#   ./gcp_projects.sh apis_list <project_id>                      # list enabled APIs
#   ./gcp_projects.sh quota_check <project_id> <region>           # inspect regional quotas
#   ./gcp_projects.sh org_policies <project_id>                   # list org policies on project
#   ./gcp_projects.sh full_setup <project_id> <billing_id>        # end-to-end: create + link + enable core APIs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Core APIs needed for Gemma 4 fine-tuning
GEMMA_APIS=(
  aiplatform.googleapis.com
  storage.googleapis.com
  compute.googleapis.com
  cloudbuild.googleapis.com
  artifactregistry.googleapis.com
  cloudresourcemanager.googleapis.com
  iam.googleapis.com
  logging.googleapis.com
  monitoring.googleapis.com
)

if [ $# -lt 1 ]; then
  grep '^#   \./gcp_projects' "${BASH_SOURCE[0]}" | sed 's/^#   /  /' >&2
  exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in

  # 1. List all projects the authenticated account can see.
  list)
    gcloud projects list \
      --format="table(projectId:label=PROJECT_ID,name:label=NAME,lifecycleState:label=STATUS)"
    ;;

  # 2. Create a new project, optionally with a display name.
  create)
    if [ $# -lt 1 ]; then echo "Usage: create <project_id> [display_name]" >&2; exit 1; fi
    PROJECT_ID="$1"
    DISPLAY_NAME="${2:-$1}"
    echo "Creating project: $PROJECT_ID (\"$DISPLAY_NAME\")..." >&2
    gcloud projects create "$PROJECT_ID" --name="$DISPLAY_NAME"
    echo "Done. Set as default with: ./gcp_projects.sh set_default $PROJECT_ID" >&2
    ;;

  # 3. Describe: Show project status (ACTIVE / DELETE_REQUESTED), parent org, labels.
  describe)
    if [ $# -ne 1 ]; then echo "Usage: describe <project_id>" >&2; exit 1; fi
    gcloud projects describe "$1"
    ;;

  # 4. Set Default: Avoid passing --project on every subsequent command.
  set_default)
    if [ $# -ne 1 ]; then echo "Usage: set_default <project_id>" >&2; exit 1; fi
    gcloud config set project "$1"
    echo "Default project set to: $1" >&2
    ;;

  # 5. Delete: Soft-delete a project. Resources persist for 30 days, billing stops.
  delete)
    if [ $# -ne 1 ]; then echo "Usage: delete <project_id>" >&2; exit 1; fi
    echo "WARNING: This soft-deletes $1. Restore within 30 days with: restore $1" >&2
    read -r -p "Type the project ID to confirm: " CONFIRM
    if [ "$CONFIRM" != "$1" ]; then echo "Aborted." >&2; exit 1; fi
    gcloud projects delete "$1"
    ;;

  # 6. Restore: Recover a soft-deleted project within the 30-day window.
  restore)
    if [ $# -ne 1 ]; then echo "Usage: restore <project_id>" >&2; exit 1; fi
    gcloud projects undelete "$1"
    echo "Project $1 restored." >&2
    ;;

  # 7. Billing Status: Check whether billing is enabled and which account is linked.
  billing_status)
    if [ $# -ne 1 ]; then echo "Usage: billing_status <project_id>" >&2; exit 1; fi
    gcloud beta billing projects describe "$1"
    ;;

  # 8. Billing Link: Connect a project to a billing account. Required for paid APIs.
  billing_link)
    if [ $# -ne 2 ]; then echo "Usage: billing_link <project_id> <billing_account_id>" >&2; exit 1; fi
    echo "Linking $1 to billing account $2..." >&2
    gcloud beta billing projects link "$1" --billing-account="$2"
    echo "Billing linked successfully." >&2
    ;;

  # 9. Billing Unlink: Disable billing for a project (stops all chargeable resources).
  billing_unlink)
    if [ $# -ne 1 ]; then echo "Usage: billing_unlink <project_id>" >&2; exit 1; fi
    echo "WARNING: Disabling billing will stop all paid services in $1." >&2
    read -r -p "Confirm project ID: " CONFIRM
    if [ "$CONFIRM" != "$1" ]; then echo "Aborted." >&2; exit 1; fi
    gcloud beta billing projects unlink "$1"
    ;;

  # 10. Billing Accounts: List all billing accounts visible to the authenticated user.
  billing_accounts)
    gcloud beta billing accounts list \
      --format="table(name:label=ACCOUNT_ID,displayName:label=NAME,open:label=OPEN,masterBillingAccount)"
    ;;

  # 11. Budget Create: Set a spend budget with threshold alerts at 50%, 90%, and 100%.
  budget_create)
    if [ $# -ne 3 ]; then echo "Usage: budget_create <billing_account_id> <budget_name> <amount_usd>" >&2; exit 1; fi
    gcloud billing budgets create \
      --billing-account="$1" \
      --display-name="$2" \
      --budget-amount="${3}USD" \
      --threshold-rule=percent=0.5 \
      --threshold-rule=percent=0.9 \
      --threshold-rule=percent=1.0
    echo "Budget '$2' created (alerts at 50%, 90%, 100% of \$${3})." >&2
    ;;

  # 12. Budget List: Show all budgets defined for a billing account.
  budget_list)
    if [ $# -ne 1 ]; then echo "Usage: budget_list <billing_account_id>" >&2; exit 1; fi
    gcloud billing budgets list --billing-account="$1"
    ;;

  # 13. Label Set: Add or update project-level labels for cost attribution.
  label_set)
    if [ $# -ne 2 ]; then echo "Usage: label_set <project_id> <key=value,...>" >&2; exit 1; fi
    gcloud projects update "$1" --update-labels="$2"
    echo "Labels updated on $1." >&2
    ;;

  # 14. Label List: Show current labels on a project.
  label_list)
    if [ $# -ne 1 ]; then echo "Usage: label_list <project_id>" >&2; exit 1; fi
    gcloud projects describe "$1" --format="yaml(labels)"
    ;;

  # 15. APIs Enable: Enable one or more APIs on a project in a single call.
  apis_enable)
    if [ $# -lt 2 ]; then echo "Usage: apis_enable <project_id> <service1> [service2...]" >&2; exit 1; fi
    PROJECT="$1"; shift
    echo "Enabling APIs on $PROJECT: $*" >&2
    gcloud services enable "$@" --project="$PROJECT"
    echo "Done." >&2
    ;;

  # 16. APIs Disable: Disable an API. Use --force to also disable dependent services.
  apis_disable)
    if [ $# -ne 2 ]; then echo "Usage: apis_disable <project_id> <service>" >&2; exit 1; fi
    echo "Disabling $2 on $1..." >&2
    gcloud services disable "$2" --project="$1" --force
    ;;

  # 17. APIs List: Show all enabled APIs on a project.
  apis_list)
    if [ $# -ne 1 ]; then echo "Usage: apis_list <project_id>" >&2; exit 1; fi
    gcloud services list --enabled --project="$1" \
      --format="table(config.name:label=SERVICE,config.title:label=TITLE)"
    ;;

  # 18. Quota Check: Print regional compute quotas — GPU quotas are listed here.
  quota_check)
    if [ $# -ne 2 ]; then echo "Usage: quota_check <project_id> <region>" >&2; exit 1; fi
    echo "=== Quotas in $2 (project: $1) ===" >&2
    gcloud compute regions describe "$2" --project="$1" --format="yaml(quotas)"
    ;;

  # 19. Org Policies: List org-level constraints applied to a project.
  #     Block common deployment failures caused by org policy violations.
  org_policies)
    if [ $# -ne 1 ]; then echo "Usage: org_policies <project_id>" >&2; exit 1; fi
    gcloud resource-manager org-policies list \
      --project="$1" \
      --format="table(constraint:label=CONSTRAINT,booleanPolicy,listPolicy)"
    ;;

  # 20. Full Setup: End-to-end provisioning — create project, link billing, enable Gemma 4 APIs.
  full_setup)
    if [ $# -ne 2 ]; then echo "Usage: full_setup <project_id> <billing_account_id>" >&2; exit 1; fi
    PROJECT="$1"
    BILLING="$2"

    echo "=== Step 1: Creating project $PROJECT ===" >&2
    gcloud projects create "$PROJECT" --name="$PROJECT" || echo "(project may already exist)" >&2

    echo "=== Step 2: Linking billing account ===" >&2
    gcloud beta billing projects link "$PROJECT" --billing-account="$BILLING"

    echo "=== Step 3: Setting as default project ===" >&2
    gcloud config set project "$PROJECT"

    echo "=== Step 4: Enabling core Gemma 4 APIs ===" >&2
    gcloud services enable "${GEMMA_APIS[@]}" --project="$PROJECT"

    echo "" >&2
    echo "=== Setup Complete ===" >&2
    echo "Project:  $PROJECT" >&2
    echo "Billing:  $BILLING" >&2
    echo "APIs:     ${GEMMA_APIS[*]}" >&2
    ;;

  *)
    echo "Unknown command: $COMMAND. Run without args to see all commands." >&2
    exit 1
    ;;
esac
