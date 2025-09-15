#!/bin/bash

# china-mirrors.sh
# Helper script with functions and configurations for adapting scripts to work better with Chinese networks

# --- Mirror Configuration ---
# GitHub mirrors
GITHUB_MIRROR="https://ghproxy.com/"
GITHUB_RAW_MIRROR="https://ghproxy.com/https://raw.githubusercontent.com/"

# Kubernetes mirrors
K8S_MIRROR="https://registry.aliyuncs.com/google_containers"
K8S_PKG_MIRROR="https://mirrors.aliyun.com/kubernetes"
K8S_RELEASE_MIRROR="https://mirrors.aliyun.com/kubernetes-release"

# Helm mirrors
HELM_MIRROR="https://mirrors.huaweicloud.com/helm"

# Docker mirrors
DOCKER_MIRROR="https://registry.docker-cn.com"

# NVIDIA mirrors
NVIDIA_MIRROR="https://mrsimonemms.github.io/nvidia-helm-mirror"

# --- Proxy Configuration ---
# Uncomment and set these variables to use a proxy
# export http_proxy="http://your-proxy:port"
# export https_proxy="http://your-proxy:port"
# export no_proxy="localhost,127.0.0.1,10.0.0.0/8,192.168.0.0/16,172.16.0.0/12"

# --- Helper Functions ---

# Function to download a file with retry and fallback
# Usage: download_with_fallback URL LOCAL_PATH [FALLBACK_URL1] [FALLBACK_URL2] ...
download_with_fallback() {
    local url="$1"
    local output_path="$2"
    shift 2
    local fallback_urls=("$@")
    local max_retries=3
    local timeout=30
    local retry_count=0
    local success=false

    echo "Downloading from $url to $output_path"
    
    # Try the primary URL with retries
    while [ $retry_count -lt $max_retries ] && [ "$success" = false ]; do
        if curl -L --connect-timeout $timeout -o "$output_path" "$url" 2>/dev/null; then
            success=true
            echo "✅ Download successful from $url"
            break
        else
            retry_count=$((retry_count + 1))
            echo "⚠️ Download failed (attempt $retry_count/$max_retries)"
            if [ $retry_count -lt $max_retries ]; then
                echo "Retrying in 3 seconds..."
                sleep 3
            fi
        fi
    done

    # If primary URL failed, try fallbacks
    if [ "$success" = false ] && [ ${#fallback_urls[@]} -gt 0 ]; then
        echo "Trying fallback URLs..."
        for fallback_url in "${fallback_urls[@]}"; do
            echo "Downloading from fallback: $fallback_url"
            if curl -L --connect-timeout $timeout -o "$output_path" "$fallback_url" 2>/dev/null; then
                success=true
                echo "✅ Download successful from fallback: $fallback_url"
                break
            else
                echo "⚠️ Fallback download failed from: $fallback_url"
            fi
        done
    fi

    if [ "$success" = true ]; then
        return 0
    else
        echo "❌ All download attempts failed"
        return 1
    fi
}

# Function to add apt repository with fallback mirrors
# Usage: add_apt_repo_with_fallback REPO_URL KEY_URL [FALLBACK_REPO_URL] [FALLBACK_KEY_URL]
add_apt_repo_with_fallback() {
    local repo_url="$1"
    local key_url="$2"
    local fallback_repo_url="$3"
    local fallback_key_url="$4"
    local tmp_key="/tmp/apt-key-$RANDOM.gpg"
    local success=false

    echo "Adding APT repository from $repo_url"
    
    # Try primary URLs
    if curl -fsSL --connect-timeout 30 "$key_url" | sudo gpg --dearmor -o "$tmp_key" 2>/dev/null; then
        if echo "$repo_url" | sudo tee /etc/apt/sources.list.d/temp-repo.list > /dev/null; then
            success=true
        fi
    fi

    # If primary failed, try fallbacks
    if [ "$success" = false ] && [ -n "$fallback_repo_url" ] && [ -n "$fallback_key_url" ]; then
        echo "Trying fallback repository: $fallback_repo_url"
        if curl -fsSL --connect-timeout 30 "$fallback_key_url" | sudo gpg --dearmor -o "$tmp_key" 2>/dev/null; then
            if echo "$fallback_repo_url" | sudo tee /etc/apt/sources.list.d/temp-repo.list > /dev/null; then
                success=true
            fi
        fi
    fi

    if [ "$success" = true ]; then
        echo "✅ Repository added successfully"
        return 0
    else
        echo "❌ Failed to add repository"
        return 1
    fi
}

# Function to add helm repo with fallback
# Usage: add_helm_repo_with_fallback REPO_NAME REPO_URL [FALLBACK_URL]
add_helm_repo_with_fallback() {
    local repo_name="$1"
    local repo_url="$2"
    local fallback_url="$3"
    local success=false
    local timeout=30

    echo "Adding Helm repository $repo_name from $repo_url"
    
    # Try primary URL
    if timeout $timeout helm repo add "$repo_name" "$repo_url" > /dev/null 2>&1; then
        success=true
        echo "✅ Helm repository $repo_name added successfully"
    else
        echo "⚠️ Failed to add Helm repository from primary URL"
        
        # Try fallback if provided
        if [ -n "$fallback_url" ]; then
            echo "Trying fallback URL: $fallback_url"
            if timeout $timeout helm repo add "$repo_name" "$fallback_url" > /dev/null 2>&1; then
                success=true
                echo "✅ Helm repository $repo_name added successfully from fallback"
            else
                echo "❌ Failed to add Helm repository from fallback URL"
            fi
        fi
    fi

    if [ "$success" = true ]; then
        helm repo update > /dev/null 2>&1
        return 0
    else
        echo "❌ Failed to add Helm repository from all sources. Please check your network connection and try again."
        return 1
    fi
}

# Check if we're running in China based on ping latency to Chinese sites vs international sites
detect_china_network() {
    local cn_site="www.baidu.com"
    local intl_site="www.google.com"
    local cn_latency=1000
    local intl_latency=1000
    
    # Test latency to Chinese site
    cn_latency=$(ping -c 1 $cn_site 2>/dev/null | grep -oP 'time=\K[0-9.]+' || echo 1000)
    
    # Test latency to international site
    intl_latency=$(ping -c 1 $intl_site 2>/dev/null | grep -oP 'time=\K[0-9.]+' || echo 1000)
    
    # If Chinese site has better latency, we're likely in China
    if (( $(echo "$cn_latency < $intl_latency" | bc -l) )); then
        return 0  # In China
    else
        return 1  # Not in China
    fi
}

# Automatically determine if we should use China mirrors
USE_CHINA_MIRRORS=false
if detect_china_network; then
    echo "🇨🇳 Chinese network detected, using China-specific mirrors"
    USE_CHINA_MIRRORS=true
else
    echo "🌍 International network detected, using default sources"
fi

# Allow override via environment variable
if [ "${FORCE_CHINA_MIRRORS}" = "true" ]; then
    echo "🔧 China mirrors forced by environment variable"
    USE_CHINA_MIRRORS=true
elif [ "${FORCE_CHINA_MIRRORS}" = "false" ]; then
    echo "🔧 China mirrors disabled by environment variable"
    USE_CHINA_MIRRORS=false
fi