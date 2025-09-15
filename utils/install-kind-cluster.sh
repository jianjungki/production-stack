#!/bin/bash

set -euo pipefail
# Note that this makes heavy use of Sam Stoelinga's guide https://www.substratus.ai/blog/kind-with-gpus
echo "Setting NVIDIA container toolkit (nvidia-ctk) to be docker's default runtime..."
# This allows Docker containers to access GPU hardware
sudo nvidia-ctk runtime configure --runtime=docker --set-as-default
echo "Restarting docker..."
sudo systemctl restart docker

echo "Allowing volume mounts..."
# This is necessary for GPU passthrough in containerized environments
sudo sed -i '/accept-nvidia-visible-devices-as-volume-mounts/c\accept-nvidia-visible-devices-as-volume-mounts = true' /etc/nvidia-container-runtime/config.toml

# Source the China mirrors helper script if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/china-mirrors.sh" ]; then
    source "$SCRIPT_DIR/china-mirrors.sh"
fi

KIND_NODE_IMAGE="kindest/node:v1.27.3@sha256:3966ac761ae0136263ffdb6cfd4db23ef8a83cba8a463690e98317add2c9ba72"
if [ "$USE_CHINA_MIRRORS" = true ]; then
    KIND_NODE_IMAGE="registry.aliyuncs.com/google_containers/kindest/node:v1.27.3@sha256:3966ac761ae0136263ffdb6cfd4db23ef8a83cba8a463690e98317add2c9ba72"
fi

kind create cluster --name single-node-cluster --config - <<EOF
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
nodes:
- role: control-plane
  image: $KIND_NODE_IMAGE
  # required for GPU workaround
  extraMounts:
    - hostPath: /dev/null
      containerPath: /var/run/nvidia-container-devices/all
EOF

echo "Adding nvidia helm repo and installing its gpu-operator helm chart..."
# Define NVIDIA Helm repo URLs
NVIDIA_REPO_URL="https://helm.ngc.nvidia.com/nvidia"
NVIDIA_REPO_MIRROR="$NVIDIA_MIRROR"

if [ "$USE_CHINA_MIRRORS" = true ] && command -v add_helm_repo_with_fallback >/dev/null 2>&1; then
    # Use our helper function with fallbacks if in China
    echo "Using China mirrors for NVIDIA Helm repo..."
    add_helm_repo_with_fallback "nvidia" "$NVIDIA_REPO_MIRROR" "$NVIDIA_REPO_URL"
else
    # Default behavior
    echo "Using official NVIDIA Helm repo..."
    helm repo add nvidia "$NVIDIA_REPO_URL" && helm repo update
fi

helm install --wait --generate-name \
     -n gpu-operator --create-namespace \
     nvidia/gpu-operator --set driver.enabled=false
