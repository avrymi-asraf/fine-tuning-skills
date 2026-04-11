#!/bin/bash
# Purpose: Manage all Google Cloud authentication and credential operations.
# Input:   COMMAND (arg 1) and optional flags.
# Output:  Credential state, token info, config profiles.
#
# Usage:
#   ./gcp_auth.sh login                        # interactive browser OAuth
#   ./gcp_auth.sh adc                          # set Application Default Credentials
#   ./gcp_auth.sh adc_quota <project_id>       # bind ADC to a quota project
#   ./gcp_auth.sh status                       # show all credentialed accounts
#   ./gcp_auth.sh token                        # print active access token (for API testing)
#   ./gcp_auth.sh revoke <email>               # remove credentials for an account
#   ./gcp_auth.sh sa_activate <key_file>       # activate a service account key
#   ./gcp_auth.sh sa_create <project> <name>   # create a new service account
#   ./gcp_auth.sh sa_list <project_id>         # list all service accounts in a project
#   ./gcp_auth.sh sa_key_create <project> <sa_email>  # generate a key file for a service account
#   ./gcp_auth.sh sa_delete <project> <sa_email>      # delete a service account
#   ./gcp_auth.sh profile_create <name>        # create a named gcloud config profile
#   ./gcp_auth.sh profile_activate <name>      # switch to a named config profile
#   ./gcp_auth.sh profile_list                 # list all config profiles
#   ./gcp_auth.sh profile_show                 # show the active config profile settings
#   ./gcp_auth.sh impersonate <sa_email>       # grant current user permission to impersonate SA
#   ./gcp_auth.sh workload_pools <project>     # list Workload Identity Federation pools
#   ./gcp_auth.sh set_region <region>          # set default compute region in config
#   ./gcp_auth.sh set_zone <zone>              # set default compute zone in config
#   ./gcp_auth.sh whoami                       # print authenticated account + project + region

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -lt 1 ]; then
  grep '^#   \./gcp_auth' "${BASH_SOURCE[0]}" | sed 's/^#   /  /' >&2
  exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in

  # 1. Login: Browser-based OAuth for human operators.
  login)
    echo "Opening browser for Google Cloud authentication..." >&2
    gcloud auth login
    ;;

  # 2. ADC: Set Application Default Credentials used by client libraries and Terraform.
  adc)
    echo "Configuring Application Default Credentials..." >&2
    gcloud auth application-default login
    ;;

  # 3. ADC Quota: Bind ADC to a specific project for billing and quota tracking.
  adc_quota)
    if [ $# -ne 1 ]; then echo "Usage: adc_quota <project_id>" >&2; exit 1; fi
    gcloud auth application-default set-quota-project "$1"
    echo "ADC quota project set to: $1" >&2
    ;;

  # 4. Status: Show all authenticated accounts and which is active.
  status)
    echo "=== Credentialed Accounts ===" >&2
    gcloud auth list
    echo "" >&2
    echo "=== Application Default Credentials ===" >&2
    gcloud auth application-default print-access-token --quiet 2>/dev/null \
      && echo "(ADC token is valid)" >&2 \
      || echo "(No ADC configured — run: ./gcp_auth.sh adc)" >&2
    ;;

  # 5. Token: Print the active bearer token. Useful for testing API calls with curl.
  token)
    gcloud auth print-access-token
    ;;

  # 6. Revoke: Remove credentials for a specific account.
  revoke)
    if [ $# -ne 1 ]; then echo "Usage: revoke <email>" >&2; exit 1; fi
    gcloud auth revoke "$1"
    echo "Revoked credentials for: $1" >&2
    ;;

  # 7. SA Activate: Activate a downloaded service account key file locally.
  sa_activate)
    if [ $# -ne 1 ]; then echo "Usage: sa_activate <key_file.json>" >&2; exit 1; fi
    if [ ! -f "$1" ]; then echo "Error: key file not found: $1" >&2; exit 1; fi
    gcloud auth activate-service-account --key-file="$1"
    echo "Service account activated from: $1" >&2
    ;;

  # 8. SA Create: Create a new service account in a project.
  sa_create)
    if [ $# -ne 2 ]; then echo "Usage: sa_create <project_id> <sa_name>" >&2; exit 1; fi
    gcloud iam service-accounts create "$2" \
      --project="$1" \
      --display-name="$2"
    echo "Created service account: $2@$1.iam.gserviceaccount.com" >&2
    ;;

  # 9. SA List: List all service accounts in a project.
  sa_list)
    if [ $# -ne 1 ]; then echo "Usage: sa_list <project_id>" >&2; exit 1; fi
    gcloud iam service-accounts list --project="$1"
    ;;

  # 10. SA Key Create: Generate a key file for a service account.
  #     WARNING: Key files are long-lived credentials. Prefer Workload Identity Federation.
  sa_key_create)
    if [ $# -ne 2 ]; then echo "Usage: sa_key_create <project_id> <sa_email>" >&2; exit 1; fi
    KEY_FILE="${2%%@*}-key.json"
    gcloud iam service-accounts keys create "$KEY_FILE" \
      --iam-account="$2" \
      --project="$1"
    echo "Key written to: $KEY_FILE" >&2
    echo "WARNING: Protect this file — treat it like a password." >&2
    ;;

  # 11. SA Delete: Permanently delete a service account.
  sa_delete)
    if [ $# -ne 2 ]; then echo "Usage: sa_delete <project_id> <sa_email>" >&2; exit 1; fi
    echo "Deleting service account: $2 in project $1" >&2
    gcloud iam service-accounts delete "$2" --project="$1" --quiet
    ;;

  # 12. Profile Create: Create a named gcloud configuration profile.
  profile_create)
    if [ $# -ne 1 ]; then echo "Usage: profile_create <name>" >&2; exit 1; fi
    gcloud config configurations create "$1"
    echo "Profile '$1' created. Activate with: ./gcp_auth.sh profile_activate $1" >&2
    ;;

  # 13. Profile Activate: Switch to a named config profile.
  profile_activate)
    if [ $# -ne 1 ]; then echo "Usage: profile_activate <name>" >&2; exit 1; fi
    gcloud config configurations activate "$1"
    echo "Active profile: $1" >&2
    ;;

  # 14. Profile List: Show all config profiles.
  profile_list)
    gcloud config configurations list
    ;;

  # 15. Profile Show: Print all settings of the currently active profile.
  profile_show)
    gcloud config list
    ;;

  # 16. Impersonate: Grant current user permission to impersonate a service account.
  impersonate)
    if [ $# -ne 1 ]; then echo "Usage: impersonate <sa_email>" >&2; exit 1; fi
    CURRENT_USER="$(gcloud auth list --filter=status:ACTIVE --format='value(account)')"
    gcloud iam service-accounts add-iam-policy-binding "$1" \
      --member="user:${CURRENT_USER}" \
      --role="roles/iam.serviceAccountTokenCreator"
    echo "User $CURRENT_USER can now impersonate: $1" >&2
    ;;

  # 17. Workload Pools: List Workload Identity Federation pools (keyless auth for CI/CD).
  workload_pools)
    if [ $# -ne 1 ]; then echo "Usage: workload_pools <project_id>" >&2; exit 1; fi
    gcloud iam workload-identity-pools list --location="global" --project="$1"
    ;;

  # 18. Set Region: Set the default compute region in the active config profile.
  set_region)
    if [ $# -ne 1 ]; then echo "Usage: set_region <region>  (e.g. us-central1)" >&2; exit 1; fi
    gcloud config set compute/region "$1"
    echo "Default region set to: $1" >&2
    ;;

  # 19. Set Zone: Set the default compute zone in the active config profile.
  set_zone)
    if [ $# -ne 1 ]; then echo "Usage: set_zone <zone>  (e.g. us-central1-a)" >&2; exit 1; fi
    gcloud config set compute/zone "$1"
    echo "Default zone set to: $1" >&2
    ;;

  # 20. Whoami: One-line summary of who you are and where you're pointed.
  whoami)
    ACCOUNT="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null || echo 'not authenticated')"
    PROJECT="$(gcloud config get-value project 2>/dev/null || echo 'none')"
    REGION="$(gcloud config get-value compute/region 2>/dev/null || echo 'none')"
    ZONE="$(gcloud config get-value compute/zone 2>/dev/null || echo 'none')"
    printf "Account : %s\nProject : %s\nRegion  : %s\nZone    : %s\n" \
      "$ACCOUNT" "$PROJECT" "$REGION" "$ZONE"
    ;;

  *)
    echo "Unknown command: $COMMAND. Run without args to see all commands." >&2
    exit 1
    ;;
esac
