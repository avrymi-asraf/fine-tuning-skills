#!/bin/bash
# Purpose: Manage IAM roles, policy bindings, and service accounts on Google Cloud.
# Input:   COMMAND (arg 1) and required arguments.
# Output:  IAM policy state, role details, binding changes.
#
# Usage:
#   ./gcp_iam.sh policy_show <project_id>                           # dump full IAM policy
#   ./gcp_iam.sh grant <project_id> <member> <role>                 # grant a role to a member
#   ./gcp_iam.sh revoke <project_id> <member> <role>                # revoke a role from a member
#   ./gcp_iam.sh member_roles <project_id> <email>                  # list all roles for a user/SA
#   ./gcp_iam.sh roles_list                                         # list all predefined GCP roles
#   ./gcp_iam.sh role_describe <role>                               # show permissions for a role
#   ./gcp_iam.sh custom_role_create <project_id> <role_id> <title> <permissions_csv>
#   ./gcp_iam.sh custom_role_list <project_id>                      # list custom roles in project
#   ./gcp_iam.sh custom_role_delete <project_id> <role_id>          # delete a custom role
#   ./gcp_iam.sh sa_grant <project_id> <sa_email> <role>            # grant role to service account
#   ./gcp_iam.sh sa_policy <project_id> <sa_email>                  # show SA's own IAM policy
#   ./gcp_iam.sh sa_allow_impersonate <sa_email> <user_email>       # let user impersonate SA
#   ./gcp_iam.sh sa_keys_list <project_id> <sa_email>               # list SA key files
#   ./gcp_iam.sh sa_keys_delete <project_id> <sa_email> <key_id>    # delete a specific SA key
#   ./gcp_iam.sh audit_log_enable <project_id> <service>            # enable data access audit logs
#   ./gcp_iam.sh audit_log_list <project_id>                        # show audit log config
#   ./gcp_iam.sh conditions_list <project_id>                       # check policies with conditions
#   ./gcp_iam.sh policy_export <project_id> <output_file>           # export policy to JSON file
#   ./gcp_iam.sh policy_import <project_id> <policy_file>           # set policy from JSON file
#   ./gcp_iam.sh least_privilege_check <project_id>                 # flag overly broad roles (owner/editor)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Broad roles that violate least-privilege — flag in audit
BROAD_ROLES=("roles/owner" "roles/editor" "roles/iam.securityAdmin")

if [ $# -lt 1 ]; then
  grep '^#   \./gcp_iam' "${BASH_SOURCE[0]}" | sed 's/^#   /  /' >&2
  exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in

  # 1. Policy Show: Dump the full IAM policy for a project in YAML.
  policy_show)
    if [ $# -ne 1 ]; then echo "Usage: policy_show <project_id>" >&2; exit 1; fi
    gcloud projects get-iam-policy "$1"
    ;;

  # 2. Grant: Add a single role binding to a principal.
  #    member format: user:<email>, serviceAccount:<email>, group:<email>
  grant)
    if [ $# -ne 3 ]; then echo "Usage: grant <project_id> <member> <role>" >&2; exit 1; fi
    echo "Granting $3 to $2 on project $1..." >&2
    gcloud projects add-iam-policy-binding "$1" \
      --member="$2" \
      --role="$3" \
      --condition=None
    echo "Done." >&2
    ;;

  # 3. Revoke: Remove a specific role binding from a principal.
  revoke)
    if [ $# -ne 3 ]; then echo "Usage: revoke <project_id> <member> <role>" >&2; exit 1; fi
    echo "Revoking $3 from $2 on project $1..." >&2
    gcloud projects remove-iam-policy-binding "$1" \
      --member="$2" \
      --role="$3"
    echo "Done." >&2
    ;;

  # 4. Member Roles: Show every role assigned to a specific user or service account.
  member_roles)
    if [ $# -ne 2 ]; then echo "Usage: member_roles <project_id> <email>" >&2; exit 1; fi
    echo "=== Roles for $2 on $1 ===" >&2
    gcloud projects get-iam-policy "$1" \
      --flatten="bindings[].members" \
      --filter="bindings.members:$2" \
      --format="table(bindings.role:label=ROLE)"
    ;;

  # 5. Roles List: List all Google-managed predefined roles (filterable with grep).
  roles_list)
    gcloud iam roles list \
      --format="table(name:label=ROLE,title:label=TITLE)"
    ;;

  # 6. Role Describe: Show every permission included in a role.
  role_describe)
    if [ $# -ne 1 ]; then echo "Usage: role_describe <role>  (e.g. roles/aiplatform.user)" >&2; exit 1; fi
    gcloud iam roles describe "$1"
    ;;

  # 7. Custom Role Create: Create a project-scoped custom role with specific permissions.
  #    permissions_csv: comma-separated list, e.g. "aiplatform.jobs.get,storage.objects.get"
  custom_role_create)
    if [ $# -ne 4 ]; then
      echo "Usage: custom_role_create <project_id> <role_id> <title> <permissions_csv>" >&2
      exit 1
    fi
    gcloud iam roles create "$2" \
      --project="$1" \
      --title="$3" \
      --description="Custom role created by gcp_iam.sh" \
      --permissions="$4" \
      --stage=GA
    echo "Custom role created: projects/$1/roles/$2" >&2
    ;;

  # 8. Custom Role List: Show all custom roles defined in a project.
  custom_role_list)
    if [ $# -ne 1 ]; then echo "Usage: custom_role_list <project_id>" >&2; exit 1; fi
    gcloud iam roles list \
      --project="$1" \
      --format="table(name:label=ROLE_NAME,title:label=TITLE,stage:label=STAGE)"
    ;;

  # 9. Custom Role Delete: Delete a custom role (must remove all bindings first).
  custom_role_delete)
    if [ $# -ne 2 ]; then echo "Usage: custom_role_delete <project_id> <role_id>" >&2; exit 1; fi
    gcloud iam roles delete "$2" --project="$1"
    echo "Deleted custom role: $2" >&2
    ;;

  # 10. SA Grant: Grant an IAM role to a service account on a project.
  sa_grant)
    if [ $# -ne 3 ]; then echo "Usage: sa_grant <project_id> <sa_email> <role>" >&2; exit 1; fi
    gcloud projects add-iam-policy-binding "$1" \
      --member="serviceAccount:$2" \
      --role="$3" \
      --condition=None
    echo "Granted $3 to serviceAccount:$2 on $1." >&2
    ;;

  # 11. SA Policy: Show the IAM policy *on* a service account (who can use/impersonate it).
  sa_policy)
    if [ $# -ne 2 ]; then echo "Usage: sa_policy <project_id> <sa_email>" >&2; exit 1; fi
    gcloud iam service-accounts get-iam-policy "$2" --project="$1"
    ;;

  # 12. SA Allow Impersonate: Grant a user the ability to impersonate a service account.
  sa_allow_impersonate)
    if [ $# -ne 2 ]; then echo "Usage: sa_allow_impersonate <sa_email> <user_email>" >&2; exit 1; fi
    gcloud iam service-accounts add-iam-policy-binding "$1" \
      --member="user:$2" \
      --role="roles/iam.serviceAccountTokenCreator"
    echo "$2 can now impersonate $1." >&2
    ;;

  # 13. SA Keys List: Show all key files (both user-managed and system-managed) for a SA.
  sa_keys_list)
    if [ $# -ne 2 ]; then echo "Usage: sa_keys_list <project_id> <sa_email>" >&2; exit 1; fi
    gcloud iam service-accounts keys list \
      --iam-account="$2" \
      --project="$1" \
      --format="table(name:label=KEY_ID,validAfterTime:label=CREATED,validBeforeTime:label=EXPIRES,keyType:label=TYPE)"
    ;;

  # 14. SA Keys Delete: Delete a specific key file by ID.
  sa_keys_delete)
    if [ $# -ne 3 ]; then echo "Usage: sa_keys_delete <project_id> <sa_email> <key_id>" >&2; exit 1; fi
    gcloud iam service-accounts keys delete "$3" \
      --iam-account="$2" \
      --project="$1" \
      --quiet
    echo "Deleted key $3 from $2." >&2
    ;;

  # 15. Audit Log Enable: Turn on data access audit logs for a specific service.
  #     Required for compliance and debugging API calls.
  audit_log_enable)
    if [ $# -ne 2 ]; then echo "Usage: audit_log_enable <project_id> <service>" >&2; exit 1; fi
    echo "Enabling DATA_READ and DATA_WRITE audit logs for $2 on $1..." >&2
    # Update policy inline using a temp file
    POLICY_FILE="$(mktemp /tmp/iam-policy-XXXXX.yaml)"
    gcloud projects get-iam-policy "$1" --format=yaml > "$POLICY_FILE"
    if ! grep -q "auditConfigs" "$POLICY_FILE"; then
      cat >> "$POLICY_FILE" <<EOF
auditConfigs:
- auditLogConfigs:
  - logType: DATA_READ
  - logType: DATA_WRITE
  service: $2
EOF
      gcloud projects set-iam-policy "$1" "$POLICY_FILE"
      echo "Audit logs enabled." >&2
    else
      echo "auditConfigs already present — edit $POLICY_FILE manually and re-import." >&2
    fi
    rm -f "$POLICY_FILE"
    ;;

  # 16. Audit Log List: Show the current audit log configuration for a project.
  audit_log_list)
    if [ $# -ne 1 ]; then echo "Usage: audit_log_list <project_id>" >&2; exit 1; fi
    gcloud projects get-iam-policy "$1" --format="yaml(auditConfigs)"
    ;;

  # 17. Conditions List: Identify any conditional IAM bindings (time-based, resource-based access).
  conditions_list)
    if [ $# -ne 1 ]; then echo "Usage: conditions_list <project_id>" >&2; exit 1; fi
    gcloud projects get-iam-policy "$1" \
      --flatten="bindings[].members" \
      --filter="bindings.condition:*" \
      --format="table(bindings.role:label=ROLE,bindings.members:label=MEMBER,bindings.condition.title:label=CONDITION)"
    ;;

  # 18. Policy Export: Save the current IAM policy to a JSON file (for backup or diff).
  policy_export)
    if [ $# -ne 2 ]; then echo "Usage: policy_export <project_id> <output_file.json>" >&2; exit 1; fi
    gcloud projects get-iam-policy "$1" --format=json > "$2"
    echo "IAM policy exported to: $2" >&2
    ;;

  # 19. Policy Import: Apply a saved IAM policy JSON file to replace the project's policy.
  #     WARNING: This is a full replacement. Test in a non-production project first.
  policy_import)
    if [ $# -ne 2 ]; then echo "Usage: policy_import <project_id> <policy_file.json>" >&2; exit 1; fi
    if [ ! -f "$2" ]; then echo "Error: policy file not found: $2" >&2; exit 1; fi
    echo "WARNING: This will fully replace the IAM policy on $1." >&2
    read -r -p "Type project ID to confirm: " CONFIRM
    if [ "$CONFIRM" != "$1" ]; then echo "Aborted." >&2; exit 1; fi
    gcloud projects set-iam-policy "$1" "$2"
    echo "IAM policy applied to $1." >&2
    ;;

  # 20. Least Privilege Check: Flag accounts with overly broad roles (owner, editor, securityAdmin).
  #     Run this as a routine audit step before deploying production workloads.
  least_privilege_check)
    if [ $# -ne 1 ]; then echo "Usage: least_privilege_check <project_id>" >&2; exit 1; fi
    echo "=== Least-Privilege Audit for $1 ===" >&2
    FOUND=0
    for ROLE in "${BROAD_ROLES[@]}"; do
      MEMBERS="$(gcloud projects get-iam-policy "$1" \
        --flatten="bindings[].members" \
        --filter="bindings.role=$ROLE" \
        --format="value(bindings.members)" 2>/dev/null)"
      if [ -n "$MEMBERS" ]; then
        echo "WARN: Role $ROLE is assigned to:" >&2
        echo "$MEMBERS" | while IFS= read -r M; do echo "  - $M" >&2; done
        FOUND=1
      fi
    done
    if [ "$FOUND" -eq 0 ]; then
      echo "OK: No overly broad roles detected." >&2
    else
      echo "" >&2
      echo "Action: Replace broad roles with scoped alternatives (e.g. roles/aiplatform.user)." >&2
    fi
    ;;

  *)
    echo "Unknown command: $COMMAND. Run without args to see all commands." >&2
    exit 1
    ;;
esac
