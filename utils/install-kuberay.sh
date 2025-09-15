#!/bin/bash

set -e

# original kuberay installation reference: https://github.com/ray-project/kuberay?tab=readme-ov-file#helm-charts

# Source the China mirrors helper script if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/china-mirrors.sh" ]; then
    source "$SCRIPT_DIR/china-mirrors.sh"
fi

# Define KubeRay Helm repo URLs
KUBERAY_REPO_URL="https://ray-project.github.io/kuberay-helm/"
KUBERAY_REPO_MIRROR="https://finops-helm.pkg.coding.net/repository/helm/kuberay/"

# Define KubeRay version
KUBERAY_VERSION="1.2.0"

echo "Adding KubeRay Helm repository..."

if [ "$USE_CHINA_MIRRORS" = true ] && command -v add_helm_repo_with_fallback >/dev/null 2>&1; then
    # Use our helper function with fallbacks if in China
    add_helm_repo_with_fallback "kuberay" "$KUBERAY_REPO_MIRROR" "$KUBERAY_REPO_URL"
else
    # Default behavior
    helm repo add kuberay "$KUBERAY_REPO_URL"
    helm repo update
fi

# Confirm the repo exists
echo "Confirming KubeRay repository is available..."
helm search repo kuberay --devel

# Install both CRDs and KubeRay operator
echo "Installing KubeRay operator version ${KUBERAY_VERSION}..."
helm install kuberay-operator kuberay/kuberay-operator --version "$KUBERAY_VERSION" --timeout 15m

# Check the KubeRay operator Pod
echo "Checking KubeRay operator pod status..."
kubectl get pods -A | grep kuberay-operator

echo "KubeRay installation completed"
