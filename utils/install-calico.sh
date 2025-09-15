#!/bin/bash

set -e

# Refer to https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart
# for more information.

# Source the China mirrors helper script if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/china-mirrors.sh" ]; then
    source "$SCRIPT_DIR/china-mirrors.sh"
fi

# Define Calico version and URLs
CALICO_VERSION="v3.30.0"
TIGERA_OPERATOR_URL="https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"
CUSTOM_RESOURCES_URL="https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml"

# Define mirror URLs
TIGERA_OPERATOR_MIRROR="${GITHUB_RAW_MIRROR}projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"
CUSTOM_RESOURCES_MIRROR="${GITHUB_RAW_MIRROR}projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml"

# Create temporary directory for manifest files
TMP_DIR=$(mktemp -d)
TIGERA_OPERATOR_FILE="${TMP_DIR}/tigera-operator.yaml"
CUSTOM_RESOURCES_FILE="${TMP_DIR}/custom-resources.yaml"

echo "Downloading Calico manifest files..."

if [ "$USE_CHINA_MIRRORS" = true ] && command -v download_with_fallback >/dev/null 2>&1; then
    # Use our helper function with fallbacks if in China
    echo "Using China mirrors for Calico manifests..."
    download_with_fallback "$TIGERA_OPERATOR_MIRROR" "$TIGERA_OPERATOR_FILE" "$TIGERA_OPERATOR_URL"
    download_with_fallback "$CUSTOM_RESOURCES_MIRROR" "$CUSTOM_RESOURCES_FILE" "$CUSTOM_RESOURCES_URL"
else
    # Default behavior
    echo "Using official Calico GitHub repository..."
    curl -L -o "$TIGERA_OPERATOR_FILE" "$TIGERA_OPERATOR_URL" || {
        echo "Failed to download tigera-operator.yaml"
        exit 1
    }
    curl -L -o "$CUSTOM_RESOURCES_FILE" "$CUSTOM_RESOURCES_URL" || {
        echo "Failed to download custom-resources.yaml"
        exit 1
    }
fi

# Install the Tigera operator and custom resource definitions:
echo "Installing Tigera operator..."
kubectl create -f "$TIGERA_OPERATOR_FILE" || echo "Tigera operator may already be installed"

# Install Calico by creating the necessary custom resources:
echo "Installing Calico custom resources..."
kubectl create -f "$CUSTOM_RESOURCES_FILE" || echo "Calico custom resources may already be installed"

# Clean up temporary files
rm -rf "$TMP_DIR"

echo "Calico installation completed"
