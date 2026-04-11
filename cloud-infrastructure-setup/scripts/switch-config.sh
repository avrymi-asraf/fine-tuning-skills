#!/bin/bash
# switch-config.sh - Easily switch between gcloud configurations for multi-project setups
#
# Usage: ./switch-config.sh [config-name]
#        ./switch-config.sh --list

set -e

list_configs() {
    echo "Available gcloud configurations:"
    echo ""
    gcloud config configurations list
}

switch_config() {
    local config_name="$1"
    
    # Check if config exists
    if ! gcloud config configurations list --format="value(name)" | grep -q "^${config_name}$"; then
        echo "Error: Configuration '$config_name' does not exist"
        echo ""
        echo "Available configurations:"
        gcloud config configurations list --format="value(name)"
        exit 1
    fi
    
    echo "Switching to configuration: $config_name"
    gcloud config configurations activate "$config_name"
    
    echo ""
    echo "Active configuration:"
    gcloud config list
}

create_config() {
    local config_name="$1"
    local project_id="$2"
    local region="${3:-us-central1}"
    
    echo "Creating new configuration: $config_name"
    
    gcloud config configurations create "$config_name"
    
    if [ -n "$project_id" ]; then
        gcloud config set project "$project_id"
    fi
    
    gcloud config set compute/region "$region"
    
    echo ""
    echo "Configuration created. Current settings:"
    gcloud config list
}

# Main
case "${1:-}" in
    --list|-l)
        list_configs
        ;;
    --create|-c)
        if [ -z "$2" ]; then
            echo "Usage: $0 --create <config-name> [project-id] [region]"
            exit 1
        fi
        create_config "$2" "${3:-}" "${4:-us-central1}"
        ;;
    "")
        # Show current config and list others
        echo "Current configuration:"
        gcloud config configurations list --filter="is_active=true"
        echo ""
        echo "All configurations:"
        gcloud config configurations list
        echo ""
        echo "Usage:"
        echo "  $0 <config-name>     - Switch to configuration"
        echo "  $0 --list           - List all configurations"
        echo "  $0 --create <name>  - Create new configuration"
        ;;
    *)
        switch_config "$1"
        ;;
esac
