#!/bin/bash
# Purpose: Tool for managing Google Cloud Account operations (20 specific items/capabilities).
# Input:   COMMAND (arg 1) alongside any additional args.
# Output:  Executes respective gcloud actions.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <command> [args...]" >&2
  echo "Available Commands (20 Items):" >&2
  echo "  1.  auth_login                 - Interactively authenticate to Google Cloud" >&2
  echo "  2.  auth_adc                   - Set Application Default Credentials" >&2
  echo "  3.  check_active_account       - Show current active account" >&2
  echo "  4.  list_projects              - List all GCP projects" >&2
  echo "  5.  create_project             - Create a new project <project_id>" >&2
  echo "  6.  set_project                - Set default project <project_id>" >&2
  echo "  7.  describe_project           - Show project metadata <project_id>" >&2
  echo "  8.  list_billing_accounts      - List all billing accounts available" >&2
  echo "  9.  get_billing_info           - Check billing link for project <project_id>" >&2
  echo "  10. link_billing_account       - Link project to billing account <project_id> <billing_account_id>" >&2
  echo "  11. enable_billing_api         - Enable billing API for <project_id>" >&2
  echo "  12. check_iam_policy           - View IAM policy for <project_id>" >&2
  echo "  13. add_iam_binding            - Add IAM user to project <project_id> <user_email> <role>" >&2
  echo "  14. list_enabled_services      - List enabled APIs for <project_id>" >&2
  echo "  15. enable_service             - Enable specific API <project_id> <service>" >&2
  echo "  16. disable_service            - Disable specific API <project_id> <service>" >&2
  echo "  17. list_regions               - List available compute regions <project_id>" >&2
  echo "  18. list_zones                 - List available compute zones <project_id>" >&2
  echo "  19. describe_quotas            - Check compute quotas <project_id> <region>" >&2
  echo "  20. full_account_status        - Complete diagnostic of auth, config, and projects" >&2
  exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
  # 1. Auth Login: Validates identity and connects the CLI tool to the account.
  auth_login)
    echo "Authenticating via web browser..." >&2
    gcloud auth login
    ;;
  
  # 2. Application Default Credentials: Sets local credentials for libraries (like Python's google-cloud) to utilize.
  auth_adc)
    echo "Configuring ADC for local code execution..." >&2
    gcloud auth application-default login
    ;;

  # 3. Check Active Account: Returns the currently authenticated user preventing unintended changes in other accounts.
  check_active_account)
    gcloud auth list --filter=status:ACTIVE --format="value(account)"
    ;;

  # 4. List Projects: Displays all organizational projects attached to your Google Cloud Account.
  list_projects)
    gcloud projects list
    ;;

  # 5. Create Project: Bootstraps an operational boundary within your account.
  create_project)
    if [ $# -ne 1 ]; then echo "Usage: create_project <project_id>" >&2; exit 1; fi
    gcloud projects create "$1"
    ;;

  # 6. Set Default Project: Avoids needing to pass --project in subsequent commands.
  set_project)
    if [ $# -ne 1 ]; then echo "Usage: set_project <project_id>" >&2; exit 1; fi
    gcloud config set project "$1"
    ;;

  # 7. Describe Project: Gets current project statuses (ACTIVE, SUSPENDED), identifying account suspensions.
  describe_project)
    if [ $# -ne 1 ]; then echo "Usage: describe_project <project_id>" >&2; exit 1; fi
    gcloud projects describe "$1"
    ;;

  # 8. List Billing Accounts: Retrieves payment entities to know which to link.
  list_billing_accounts)
    gcloud beta billing accounts list
    ;;

  # 9. Get Billing Info: Validates whether a specific project is financially active.
  get_billing_info)
    if [ $# -ne 1 ]; then echo "Usage: get_billing_info <project_id>" >&2; exit 1; fi
    gcloud beta billing projects describe "$1"
    ;;

  # 10. Link Billing Account: Most crucial task for unlocking paid features.
  link_billing_account)
    if [ $# -ne 2 ]; then echo "Usage: link_billing_account <project_id> <billing_account_id>" >&2; exit 1; fi
    gcloud beta billing projects link "$1" --billing-account "$2"
    ;;

  # 11. Enable Billing API: Necessary before executing billing operations programmatically.
  enable_billing_api)
    if [ $# -ne 1 ]; then echo "Usage: enable_billing_api <project_id>" >&2; exit 1; fi
    gcloud services enable cloudbilling.googleapis.com --project="$1"
    ;;

  # 12. Check IAM Policy: Determines which members have which roles in the account.
  check_iam_policy)
    if [ $# -ne 1 ]; then echo "Usage: check_iam_policy <project_id>" >&2; exit 1; fi
    gcloud projects get-iam-policy "$1"
    ;;

  # 13. Add IAM Binding: Safely delegates permissions to collaborators or service accounts.
  add_iam_binding)
    if [ $# -ne 3 ]; then echo "Usage: add_iam_binding <project_id> <user_email> <role>" >&2; exit 1; fi
    gcloud projects add-iam-policy-binding "$1" --member="user:$2" --role="$3"
    ;;

  # 14. List Enabled Services: Checks currently active APIs consuming billing.
  list_enabled_services)
    if [ $# -ne 1 ]; then echo "Usage: list_enabled_services <project_id>" >&2; exit 1; fi
    gcloud services list --enabled --project="$1"
    ;;

  # 15. Enable Service: Boots up necessary backend services (e.g., Compute Engine) for deployment.
  enable_service)
    if [ $# -ne 2 ]; then echo "Usage: enable_service <project_id> <service_dns_name>" >&2; exit 1; fi
    gcloud services enable "$2" --project="$1"
    ;;

  # 16. Disable Service: Turns off unnecessary resources aiding billing reduction.
  disable_service)
    if [ $# -ne 2 ]; then echo "Usage: disable_service <project_id> <service_dns_name>" >&2; exit 1; fi
    gcloud services disable "$2" --project="$1"
    ;;

  # 17. List Regions: Displays valid geographies for deploying Gemma 4 for correct billing optimization.
  list_regions)
    if [ $# -ne 1 ]; then echo "Usage: list_regions <project_id>" >&2; exit 1; fi
    gcloud compute regions list --project="$1"
    ;;

  # 18. List Zones: Drills down into specific data centers for fault tolerance.
  list_zones)
    if [ $# -ne 1 ]; then echo "Usage: list_zones <project_id>" >&2; exit 1; fi
    gcloud compute zones list --project="$1"
    ;;

  # 19. Describe Quotas: Ensures account is allowed sufficient GPU allocations for Gemma 4 before doing work.
  describe_quotas)
    if [ $# -ne 2 ]; then echo "Usage: describe_quotas <project_id> <region>" >&2; exit 1; fi
    gcloud compute regions describe "$2" --project="$1" --format="yaml(quotas)"
    ;;

  # 20. Full Account Status: Combined validation reporting the complete picture of your setup.
  full_account_status)
    echo "--- Active Account ---" >&2
    gcloud auth list --filter=status:ACTIVE
    echo -e "\n--- Default Configuration ---" >&2
    gcloud config list
    echo -e "\n--- Current Projects ---" >&2
    gcloud projects list
    ;;

  *)
    echo "Unknown command: $COMMAND. Run without args to see the 20 available items." >&2
    exit 1
    ;;
esac
