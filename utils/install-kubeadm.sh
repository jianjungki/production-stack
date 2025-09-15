#!/bin/bash

# Refer to https://v1-32.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
# for more detailed explanation of kubeadm installation.
# Following instructions are for linux distributions like Ubuntu, Debian, etc.
# This script is from above official documentation, but modified to work with Debian 11 (bullseye).

# Source the China mirrors helper script if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/china-mirrors.sh" ]; then
    source "$SCRIPT_DIR/china-mirrors.sh"
fi

sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command
sudo mkdir -p -m 755 /etc/apt/keyrings

# Define URLs - original and mirrors
K8S_VERSION="v1.32"
OFFICIAL_KEY_URL="https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key"
OFFICIAL_REPO="deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /"

# Aliyun mirror URLs
ALIYUN_KEY_URL="https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg"
ALIYUN_REPO="deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main"

# TUNA mirror URLs
TUNA_KEY_URL="https://mirrors.tuna.tsinghua.edu.cn/kubernetes/apt/doc/apt-key.gpg"
TUNA_REPO="deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.tuna.tsinghua.edu.cn/kubernetes/apt/ kubernetes-xenial main"

if [ "$USE_CHINA_MIRRORS" = true ] && command -v add_apt_repo_with_fallback >/dev/null 2>&1; then
    echo "Using China mirrors for Kubernetes packages..."
    
    # Try Aliyun mirror first, then TUNA mirror, then official as last resort
    if ! add_apt_repo_with_fallback "$ALIYUN_REPO" "$ALIYUN_KEY_URL" "$TUNA_REPO" "$TUNA_KEY_URL"; then
        echo "Failed to add repository from China mirrors, falling back to official source..."
        curl -fsSL "$OFFICIAL_KEY_URL" | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        echo "$OFFICIAL_REPO" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    fi
else
    # Default behavior - use official source
    echo "Using official Kubernetes package repository..."
    curl -fsSL "$OFFICIAL_KEY_URL" | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "$OFFICIAL_REPO" | sudo tee /etc/apt/sources.list.d/kubernetes.list
fi

# Update the apt package index, install kubelet, kubeadm and kubectl, and pin their version:
echo "Updating package index and installing Kubernetes components..."
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# (Optional) Enable the kubelet service before running kubeadm:
echo "Enabling kubelet service..."
sudo systemctl enable --now kubelet
