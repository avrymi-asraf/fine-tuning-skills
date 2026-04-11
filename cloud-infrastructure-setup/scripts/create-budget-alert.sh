#!/bin/bash
# Purpose: Create billing budget alerts for ML projects
# Usage:   ./create-budget-alert.sh BILLING_ACCOUNT_ID [BUDGET_AMOUNT] [PROJECT_ID]
# Example: ./create-budget-alert.sh XXXXXX-XXXXXX-XXXXXX 1000 my-project

set -euo pipefail

BILLING_ACCOUNT="${1:-}"
BUDGET_AMOUNT="${2:-1000}"
PROJECT_ID="${3:-$(gcloud config get-value project 2>/dev/null || true)}"

if [ -z "$BILLING_ACCOUNT" ]; then
    echo "Usage: $0 BILLING_ACCOUNT_ID [BUDGET_AMOUNT] [PROJECT_ID]" >&2
    echo "" >&2
    echo "Example:" >&2
    echo "  $0 XXXXXX-XXXXXX-XXXXXX 1000 my-project" >&2
    echo "" >&2
    echo "To find your billing account ID:" >&2
    echo "  gcloud billing accounts list" >&2
    exit 1
fi

if [ -z "$PROJECT_ID" ]; then
    echo "Error: No project specified and no default project configured" >&2
    exit 1
fi

echo "Creating budget alert for:"
echo "  Billing Account: $BILLING_ACCOUNT"
echo "  Project: $PROJECT_ID"
echo "  Budget Amount: \$${BUDGET_AMOUNT} USD"
echo ""

# Create budget with threshold rules
BUDGET_NAME="ML Training Budget - ${PROJECT_ID}"

echo "Creating budget: $BUDGET_NAME"

# Create the budget
if gcloud billing budgets create \
    --billing-account="$BILLING_ACCOUNT" \
    --display-name="$BUDGET_NAME" \
    --budget-amount="${BUDGET_AMOUNT}USD" \
    --threshold-rule=percent=50 \
    --threshold-rule=percent=80 \
    --threshold-rule=percent=100; then
    
    echo ""
    echo "✓ Budget created successfully!"
else
    echo ""
    echo "✗ Failed to create budget"
    echo ""
    echo "Make sure you have billing administrator permissions"
    exit 1
fi

echo ""
echo "Budget alerts configured at:"
echo "  - 50% (\$$((BUDGET_AMOUNT / 2)))"
echo "  - 80% (\$$((BUDGET_AMOUNT * 8 / 10)))"
echo "  - 100% (\$$BUDGET_AMOUNT)"
echo ""
echo "To add Pub/Sub notifications for programmatic handling:"
echo "  1. Create a topic:"
echo "     gcloud pubsub topics create budget-alerts --project=$PROJECT_ID"
echo ""
echo "  2. Create budget with Pub/Sub:"
echo "     gcloud billing budgets create \\"
echo "       --billing-account=$BILLING_ACCOUNT \\"
echo "       --display-name='Budget with Pub/Sub' \\"
echo "       --budget-amount=${BUDGET_AMOUNT}USD \\"
echo "       --threshold-rule=percent=80 \\"
echo "       --pubsub-topic=projects/$PROJECT_ID/topics/budget-alerts"
