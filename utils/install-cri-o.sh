#!/bin/bash

# Refer to https://github.com/cri-o/packaging/blob/main/README.md#distributions-using-deb-packages
# and
# https://github.com/cri-o/cri-o/blob/main/contrib/cni/README.md#configuration-directory
# for more information.

# Source the China mirrors helper script if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/china-mirrors.sh" ]; then
    source "$SCRIPT_DIR/china-mirrors.sh"
fi

# Install the dependencies for adding repositories
sudo apt-get update
sudo apt-get install -y software-properties-common curl

export CRIO_VERSION=v1.32

# Define CRI-O repo URLs
CRIO_KEY_URL="https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$CRIO_VERSION/deb/Release.key"
CRIO_REPO_URL="deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$CRIO_VERSION/deb/ /"
CRIO_MIRROR_KEY_URL="https://mirrors.tuna.tsinghua.edu.cn/opensuse/repositories/isv:/cri-o:/stable:/$CRIO_VERSION/deb/Release.key"
CRIO_MIRROR_REPO_URL="deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://mirrors.tuna.tsinghua.edu.cn/opensuse/repositories/isv:/cri-o:/stable:/$CRIO_VERSION/deb/ /"

# Add the CRI-O repository
if [ "$USE_CHINA_MIRRORS" = true ] && command -v add_apt_repo_with_fallback >/dev/null 2>&1; then
    echo "Using China mirrors for CRI-O repository..."
    add_apt_repo_with_fallback "$CRIO_MIRROR_REPO_URL" "$CRIO_MIRROR_KEY_URL" "$CRIO_REPO_URL" "$CRIO_KEY_URL"
else
    echo "Using official CRI-O repository..."
    curl -fsSL "$CRIO_KEY_URL" | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
    echo "$CRIO_REPO_URL" | sudo tee /etc/apt/sources.list.d/cri-o.list
fi

# Install the packages
sudo apt-get update
sudo apt-get install -y cri-o

# Update crio config by creating (or editing) /etc/crio/crio.conf
PAUSE_IMAGE="registry.k8s.io/pause:3.10"
if [ "$USE_CHINA_MIRRORS" = true ]; then
    PAUSE_IMAGE="registry.aliyuncs.com/google_containers/pause:3.10"
fi

sudo tee /etc/crio/crio.conf > /dev/null <<EOF
[crio.image]
pause_image="$PAUSE_IMAGE"

[crio.runtime]
conmon_cgroup = "pod"
cgroup_manager = "systemd"
EOF

# Start CRI-O
sudo systemctl start crio.service

sudo swapoff -a
sudo modprobe br_netfilter
sudo sysctl -w net.ipv4.ip_forward=1

# Apply sysctl params without reboot
sudo sysctl --system

# Verify that net.ipv4.ip_forward is set to 1 with:
sudo sysctl net.ipv4.ip_forward
