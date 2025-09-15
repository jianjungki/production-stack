#!/bin/bash

set -e

# Source the China mirrors helper script if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/china-mirrors.sh" ]; then
    source "$SCRIPT_DIR/china-mirrors.sh"
fi

helm_exists() {
    which helm > /dev/null 2>&1
}

# Skip if already installed helm
if helm_exists; then
    echo "Helm is installed"
    exit 0
fi

# Install Helm
echo "Downloading Helm installation script..."

# Define URLs - original and mirrors
HELM_SCRIPT_URL="https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3"
HELM_SCRIPT_MIRROR1="${GITHUB_RAW_MIRROR}helm/helm/main/scripts/get-helm-3"
HELM_SCRIPT_MIRROR2="https://gitee.com/mirrors/helm/raw/main/scripts/get-helm-3"

if [ "$USE_CHINA_MIRRORS" = true ] && command -v download_with_fallback >/dev/null 2>&1; then
    # Use our helper function with fallbacks if in China
    download_with_fallback "$HELM_SCRIPT_MIRROR1" "get_helm.sh" "$HELM_SCRIPT_MIRROR2" "$HELM_SCRIPT_URL"
else
    # Default behavior
    curl -fsSL -o get_helm.sh "$HELM_SCRIPT_URL" || {
        echo "Failed to download Helm installation script"
        exit 1
    }
fi

chmod 700 get_helm.sh

# Set HELM_MIRROR environment variable for the get_helm.sh script if in China
if [ "$USE_CHINA_MIRRORS" = true ]; then
    echo "Using Huawei Cloud Helm mirror for installation"
    export HELM_MIRROR="$HELM_MIRROR"
fi

./get_helm.sh

# Test helm installation
if helm_exists; then
    echo "Helm is successfully installed"
else
    echo "Helm installation failed"
    exit 1
fi
