#!/bin/bash

set -e

# Source the China mirrors helper script if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/china-mirrors.sh" ]; then
    source "$SCRIPT_DIR/china-mirrors.sh"
fi

KUBECTL_DIR="$HOME/.local/bin"
KUBECTL_PATH="$KUBECTL_DIR/kubectl"

kubectl_exists() {
    command -v kubectl >/dev/null 2>&1
}

# If kubectl is already installed, exit
if kubectl_exists; then
    echo "kubectl is already installed"
    exit 0
fi

# Ensure the target directory exists
mkdir -p "$KUBECTL_DIR"

# Get stable kubectl version
get_stable_version() {
    local version=""
    
    # Try Kubernetes official site first
    version=$(curl -L -s --connect-timeout 10 https://dl.k8s.io/release/stable.txt 2>/dev/null)
    
    # If that fails, try Aliyun mirror
    if [ -z "$version" ]; then
        echo "Failed to get stable version from official site, trying Aliyun mirror..."
        version=$(curl -L -s --connect-timeout 10 https://mirrors.aliyun.com/kubernetes/release/stable.txt 2>/dev/null)
    fi
    
    # If still no version, use a hardcoded fallback
    if [ -z "$version" ]; then
        echo "Failed to get stable version from mirrors, using fallback version..."
        version="v1.29.0"  # Fallback to a known version
    fi
    
    echo "$version"
}

STABLE_VERSION=$(get_stable_version)
echo "Using kubectl version: $STABLE_VERSION"

# Define URLs - original and mirrors
KUBECTL_URL="https://dl.k8s.io/release/${STABLE_VERSION}/bin/linux/amd64/kubectl"
KUBECTL_MIRROR1="${K8S_RELEASE_MIRROR}/release/${STABLE_VERSION}/bin/linux/amd64/kubectl"
KUBECTL_MIRROR2="https://mirrors.tuna.tsinghua.edu.cn/kubernetes/release/${STABLE_VERSION}/bin/linux/amd64/kubectl"

# Install kubectl
if [ "$USE_CHINA_MIRRORS" = true ] && command -v download_with_fallback >/dev/null 2>&1; then
    # Use our helper function with fallbacks if in China
    echo "Using China mirrors for kubectl download..."
    download_with_fallback "$KUBECTL_MIRROR1" "kubectl" "$KUBECTL_MIRROR2" "$KUBECTL_URL"
else
    # Default behavior
    echo "Using official Kubernetes download site..."
    curl -LO "$KUBECTL_URL" || {
        echo "Failed to download kubectl"
        exit 1
    }
fi

chmod +x kubectl
mv kubectl "$KUBECTL_PATH"

# Add to PATH if not already included
if ! echo "$PATH" | grep -q "$KUBECTL_DIR"; then
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.bashrc
    echo "export PATH=\"$HOME/.local/bin:\$PATH\"" >> ~/.profile
    export PATH="$HOME/.local/bin:$PATH"
fi

# Test the installation
if kubectl_exists; then
    echo "kubectl installed successfully in $KUBECTL_PATH"
else
    echo "kubectl installation failed"
    exit 1
fi
