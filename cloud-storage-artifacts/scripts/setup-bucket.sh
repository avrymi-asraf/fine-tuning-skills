#!/bin/bash
#
# setup-bucket.sh - Create and configure cloud storage buckets for ML workflows
#
# Usage: ./setup-bucket.sh [gcs|s3|azure] [bucket-name] [options]
#
# Examples:
#   ./setup-bucket.sh gcs my-project-ml-artifacts --location=us-central1
#   ./setup-bucket.sh s3 my-project-ml-artifacts --region=us-east-1
#   ./setup-bucket.sh azure myprojectmlartifacts --resource-group=my-rg
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
PROVIDER=""
BUCKET_NAME=""
LOCATION=""
STORAGE_CLASS="STANDARD"
UNIFORM_ACCESS=true
ENABLE_VERSIONING=false
ENABLE_LIFECYCLE=true

# Function to print usage
usage() {
    cat << EOF
Usage: $0 [PROVIDER] [BUCKET_NAME] [OPTIONS]

Providers:
  gcs     Google Cloud Storage
  s3      Amazon S3
  azure   Azure Blob Storage

Options:
  --location=REGION       Region/location (required for GCS/Azure)
  --region=REGION         Region (alias for S3)
  --resource-group=RG     Resource group (required for Azure)
  --storage-class=CLASS   Storage class (default: STANDARD)
  --versioning            Enable object versioning
  --no-lifecycle          Disable lifecycle policy setup
  --uniform-access        Enable uniform bucket-level access (GCS only)

Examples:
  $0 gcs my-project-ml --location=us-central1
  $0 s3 my-project-ml --region=us-east-1
  $0 azure myprojectml --resource-group=my-rg --location=eastus
EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        gcs|s3|azure)
            PROVIDER="$1"
            shift
            ;;
        --location=*)
            LOCATION="${1#*=}"
            shift
            ;;
        --region=*)
            LOCATION="${1#*=}"
            shift
            ;;
        --resource-group=*)
            RESOURCE_GROUP="${1#*=}"
            shift
            ;;
        --storage-class=*)
            STORAGE_CLASS="${1#*=}"
            shift
            ;;
        --versioning)
            ENABLE_VERSIONING=true
            shift
            ;;
        --no-lifecycle)
            ENABLE_LIFECYCLE=false
            shift
            ;;
        --uniform-access)
            UNIFORM_ACCESS=true
            shift
            ;;
        --no-uniform-access)
            UNIFORM_ACCESS=false
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
        *)
            if [[ -z "$BUCKET_NAME" ]]; then
                BUCKET_NAME="$1"
            fi
            shift
            ;;
    esac
done

# Validate inputs
if [[ -z "$PROVIDER" ]] || [[ -z "$BUCKET_NAME" ]]; then
    echo -e "${RED}Error: Provider and bucket name are required${NC}"
    usage
fi

echo -e "${GREEN}Setting up $PROVIDER bucket: $BUCKET_NAME${NC}"

# ============================================================================
# GOOGLE CLOUD STORAGE
# ============================================================================
setup_gcs() {
    if [[ -z "$LOCATION" ]]; then
        echo -e "${RED}Error: --location is required for GCS${NC}"
        exit 1
    fi

    # Check if bucket exists
    if gcloud storage buckets describe "gs://$BUCKET_NAME" &>/dev/null; then
        echo -e "${YELLOW}Bucket gs://$BUCKET_NAME already exists${NC}"
    else
        echo "Creating GCS bucket..."
        gcloud storage buckets create "gs://$BUCKET_NAME" \
            --location="$LOCATION" \
            --default-storage-class="$STORAGE_CLASS"
    fi

    # Set uniform bucket-level access
    if [[ "$UNIFORM_ACCESS" == true ]]; then
        echo "Enabling uniform bucket-level access..."
        gcloud storage buckets update "gs://$BUCKET_NAME" \
            --uniform-bucket-level-access
    fi

    # Enable versioning
    if [[ "$ENABLE_VERSIONING" == true ]]; then
        echo "Enabling object versioning..."
        gcloud storage buckets update "gs://$BUCKET_NAME" \
            --versioning
    fi

    # Apply lifecycle policy
    if [[ "$ENABLE_LIFECYCLE" == true ]]; then
        apply_gcs_lifecycle
    fi

    # Set CORS for web access if needed
    echo "Setting CORS configuration..."
    cat > /tmp/cors.json << 'EOF'
[{
  "origin": ["*"],
  "method": ["GET", "HEAD"],
  "responseHeader": ["Content-Type"],
  "maxAgeSeconds": 3600
}]
EOF
    gcloud storage buckets update "gs://$BUCKET_NAME" \
        --cors-file=/tmp/cors.json 2>/dev/null || true

    echo -e "${GREEN}GCS bucket setup complete!${NC}"
    echo ""
    echo "Bucket URL: gs://$BUCKET_NAME"
    echo "Console: https://console.cloud.google.com/storage/browser/$BUCKET_NAME"
}

apply_gcs_lifecycle() {
    echo "Applying lifecycle policy..."
    
    cat > /tmp/lifecycle.json << 'LIFECYCLE'
{
  "lifecycle": {
    "rule": [
      {
        "id": "delete-temp-checkpoints",
        "action": {"type": "Delete"},
        "condition": {
          "age": 7,
          "matchesPrefix": ["checkpoints/temp/", "experiments/temp/"]
        }
      },
      {
        "id": "transition-checkpoints-to-nearline",
        "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
        "condition": {
          "age": 30,
          "matchesPrefix": ["checkpoints/"],
          "numNewerVersions": 3
        }
      },
      {
        "id": "transition-old-experiments-to-coldline",
        "action": {"type": "SetStorageClass", "storageClass": "COLDLINE"},
        "condition": {
          "age": 90,
          "matchesPrefix": ["experiments/"]
        }
      },
      {
        "id": "delete-old-logs",
        "action": {"type": "Delete"},
        "condition": {
          "age": 365,
          "matchesPrefix": ["logs/"]
        }
      }
    ]
  }
}
LIFECYCLE

    gcloud storage buckets update "gs://$BUCKET_NAME" \
        --lifecycle-file=/tmp/lifecycle.json
    
    rm -f /tmp/lifecycle.json
}

# ============================================================================
# AMAZON S3
# ============================================================================
setup_s3() {
    if [[ -z "$LOCATION" ]]; then
        echo -e "${RED}Error: --region is required for S3${NC}"
        exit 1
    fi

    # Check if bucket exists
    if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
        echo -e "${YELLOW}Bucket s3://$BUCKET_NAME already exists${NC}"
    else
        echo "Creating S3 bucket..."
        
        # us-east-1 doesn't need LocationConstraint
        if [[ "$LOCATION" == "us-east-1" ]]; then
            aws s3api create-bucket \
                --bucket "$BUCKET_NAME"
        else
            aws s3api create-bucket \
                --bucket "$BUCKET_NAME" \
                --create-bucket-configuration LocationConstraint="$LOCATION"
        fi
        
        # Block public access by default
        aws s3api put-public-access-block \
            --bucket "$BUCKET_NAME" \
            --public-access-block-configuration \
                BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
    fi

    # Enable versioning
    if [[ "$ENABLE_VERSIONING" == true ]]; then
        echo "Enabling object versioning..."
        aws s3api put-bucket-versioning \
            --bucket "$BUCKET_NAME" \
            --versioning-configuration Status=Enabled
    fi

    # Apply lifecycle policy
    if [[ "$ENABLE_LIFECYCLE" == true ]]; then
        apply_s3_lifecycle
    fi

    # Set default encryption
    echo "Setting default encryption..."
    aws s3api put-bucket-encryption \
        --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }'

    echo -e "${GREEN}S3 bucket setup complete!${NC}"
    echo ""
    echo "Bucket URL: s3://$BUCKET_NAME"
    echo "Console: https://s3.console.aws.amazon.com/s3/buckets/$BUCKET_NAME"
}

apply_s3_lifecycle() {
    echo "Applying lifecycle policy..."
    
    cat > /tmp/lifecycle.json << 'LIFECYCLE'
{
  "Rules": [
    {
      "ID": "delete-temp-checkpoints",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "checkpoints/temp/"
      },
      "Expiration": {
        "Days": 7
      }
    },
    {
      "ID": "transition-checkpoints-to-ia",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "checkpoints/"
      },
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        }
      ],
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 30
      }
    },
    {
      "ID": "transition-old-experiments-to-glacier",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "experiments/"
      },
      "Transitions": [
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        }
      ]
    },
    {
      "ID": "delete-old-logs",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "logs/"
      },
      "Expiration": {
        "Days": 365
      }
    }
  ]
}
LIFECYCLE

    aws s3api put-bucket-lifecycle-configuration \
        --bucket "$BUCKET_NAME" \
        --lifecycle-configuration file:///tmp/lifecycle.json
    
    rm -f /tmp/lifecycle.json
}

# ============================================================================
# AZURE BLOB STORAGE
# ============================================================================
setup_azure() {
    if [[ -z "$LOCATION" ]]; then
        echo -e "${RED}Error: --location is required for Azure${NC}"
        exit 1
    fi
    
    if [[ -z "${RESOURCE_GROUP:-}" ]]; then
        echo -e "${RED}Error: --resource-group is required for Azure${NC}"
        exit 1
    fi

    STORAGE_ACCOUNT="${BUCKET_NAME//-/}"
    STORAGE_ACCOUNT="${STORAGE_ACCOUNT:0:24}"
    
    echo "Using storage account name: $STORAGE_ACCOUNT"

    # Check if storage account exists
    if az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
        echo -e "${YELLOW}Storage account $STORAGE_ACCOUNT already exists${NC}"
    else
        echo "Creating Azure storage account..."
        az storage account create \
            --name "$STORAGE_ACCOUNT" \
            --resource-group "$RESOURCE_GROUP" \
            --location "$LOCATION" \
            --sku Standard_LRS \
            --kind StorageV2 \
            --access-tier Hot
    fi

    # Create container
    echo "Creating container '$BUCKET_NAME'..."
    az storage container create \
        --name "$BUCKET_NAME" \
        --account-name "$STORAGE_ACCOUNT" \
        --fail-on-exist 2>/dev/null || echo -e "${YELLOW}Container may already exist${NC}"

    # Apply lifecycle policy
    if [[ "$ENABLE_LIFECYCLE" == true ]]; then
        apply_azure_lifecycle "$STORAGE_ACCOUNT" "$RESOURCE_GROUP"
    fi

    echo -e "${GREEN}Azure Blob Storage setup complete!${NC}"
    echo ""
    echo "Container URL: https://$STORAGE_ACCOUNT.blob.core.windows.net/$BUCKET_NAME"
    echo "Portal: https://portal.azure.com/#@/resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT"
}

apply_azure_lifecycle() {
    local account="$1"
    local rg="$2"
    
    echo "Applying lifecycle policy..."
    
    cat > /tmp/lifecycle.json << LIFECYCLE
{
  "rules": [
    {
      "enabled": true,
      "name": "delete-temp-checkpoints",
      "type": "Lifecycle",
      "definition": {
        "actions": {
          "baseBlob": {
            "delete": { "daysAfterModificationGreaterThan": 7 }
          }
        },
        "filters": {
          "blobTypes": ["blockBlob"],
          "prefixMatch": ["checkpoints/temp/", "experiments/temp/"]
        }
      }
    },
    {
      "enabled": true,
      "name": "transition-to-cool",
      "type": "Lifecycle",
      "definition": {
        "actions": {
          "baseBlob": {
            "tierToCool": { "daysAfterModificationGreaterThan": 30 }
          }
        },
        "filters": {
          "blobTypes": ["blockBlob"],
          "prefixMatch": ["checkpoints/"]
        }
      }
    },
    {
      "enabled": true,
      "name": "transition-to-archive",
      "type": "Lifecycle",
      "definition": {
        "actions": {
          "baseBlob": {
            "tierToArchive": { "daysAfterModificationGreaterThan": 90 }
          }
        },
        "filters": {
          "blobTypes": ["blockBlob"],
          "prefixMatch": ["experiments/"]
        }
      }
    },
    {
      "enabled": true,
      "name": "delete-old-logs",
      "type": "Lifecycle",
      "definition": {
        "actions": {
          "baseBlob": {
            "delete": { "daysAfterModificationGreaterThan": 365 }
          }
        },
        "filters": {
          "blobTypes": ["blockBlob"],
          "prefixMatch": ["logs/"]
        }
      }
    }
  ]
}
LIFECYCLE

    az storage account management-policy create \
        --account-name "$account" \
        --resource-group "$rg" \
        --policy @/tmp/lifecycle.json || echo -e "${YELLOW}Lifecycle policy may already exist${NC}"
    
    rm -f /tmp/lifecycle.json
}

# ============================================================================
# MAIN
# ============================================================================

case $PROVIDER in
    gcs)
        setup_gcs
        ;;
    s3)
        setup_s3
        ;;
    azure)
        setup_azure
        ;;
    *)
        echo -e "${RED}Unknown provider: $PROVIDER${NC}"
        usage
        ;;
esac

echo ""
echo -e "${GREEN}Done!${NC}"
