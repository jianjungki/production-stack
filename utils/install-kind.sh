#!/bin/bash

set -e

# Source the China mirrors helper script if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/china-mirrors.sh" ]; then
    source "$SCRIPT_DIR/china-mirrors.sh"
fi

# Optionally use .local as KIND_DIR="$HOME/.local/bin"
KIND_DIR="$HOME/bin"
KIND_PATH="$KIND_DIR/kind"

kind_exists() {
    command -v kind >/dev/null 2>&1
}

# If kind is already installed, exit
if kind_exists; then
    echo "kind is already installed"
    exit 0
fi

# Ensure the target directory exists
mkdir -p "$KIND_DIR"

# Define kind version
KIND_VERSION="v0.29.0"

# Install kind (from tutorial https://kind.sigs.k8s.io/docs/user/quick-start/)
case "$(uname -m)" in
  x86_64)
    KIND_ARCH="amd64"
    ;;
  aarch64)
    KIND_ARCH="arm64"
    ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

# Define URLs - original and mirrors
KIND_URL="https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${KIND_ARCH}"
KIND_MIRROR1="${GITHUB_MIRROR}https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-${KIND_ARCH}"
KIND_MIRROR2="https://mirror.ghproxy.com/https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-${KIND_ARCH}"

echo "Downloading kind ${KIND_VERSION} for ${KIND_ARCH}..."

if [ "$USE_CHINA_MIRRORS" = true ] && command -v download_with_fallback >/dev/null 2>&1; then
    # Use our helper function with fallbacks if in China
    echo "Using China mirrors for kind download..."
    download_with_fallback "$KIND_MIRROR1" "kind" "$KIND_MIRROR2" "$KIND_URL"
else
    # Default behavior
    echo "Using official kind download site..."
    curl -Lo kind "$KIND_URL" || {
        echo "Failed to download kind"
        exit 1
    }
fi

chmod +x kind
mv kind "$KIND_PATH"

# Add to PATH if not already included
if ! echo "$PATH" | grep -q "$KIND_DIR"; then
    echo "Adding kind directory to PATH environment variable"
    echo "export PATH=\"$HOME/bin:\$PATH\"" >> ~/.bashrc
    echo "export PATH=\"$HOME/bin:\$PATH\"" >> ~/.profile
    export PATH="$HOME/bin:$PATH"
fi

# Test the installation
if kind_exists; then
    echo "kind installed successfully in $KIND_PATH"
else
    echo "kind installation failed"
    exit 1
fi
