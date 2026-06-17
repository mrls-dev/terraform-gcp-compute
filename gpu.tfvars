##########################
# GPU Environment Configuration
##########################
# Configuration for GPU-enabled instances for CUDA kernel development
# Uses RHEL 10 with NVIDIA driver auto-install (manual CUDA installation)
# Cost estimate: ~$0.50/hour with T4 GPU (or ~$0.15/hour with preemptible)

##########################
# Project Configuration
##########################
project_id         = "project-70f3c2b9-8f91-41f7-b5c"
network_project_id = "mrls-dev-network"
project_name       = "cts-sample"
environment        = "dev"

##########################
# Location Configuration
##########################
# Note: Ensure GPU availability in your selected zone
# Check: https://cloud.google.com/compute/docs/gpus/gpu-regions-zones
region = "us-central1"
zone   = "us-central1-a" # T4 GPUs available here

##########################
# Network State Configuration
##########################
network_state_bucket = "mrlsmahesh-org-terraform-state-dev"
network_state_prefix = "network/vpc/dev"

##########################
# Compute Configuration - GPU Optimized
##########################
# GPU instances require specific machine types
# n1-standard-4: Good balance for single GPU (4 vCPU, 15 GB RAM)
# n1-standard-8: Better for heavy workloads (8 vCPU, 30 GB RAM)
# a2-highgpu-1g: Optimized for A100 GPUs
machine_type = "n1-standard-4"

##########################
# GPU Configuration
##########################
# Enable GPU and configure type
enable_gpu = true
gpu_type   = "nvidia-tesla-t4" # $0.35/hour (cheapest option)
gpu_count  = 1

# RHEL does not have pre-installed drivers - enable auto-install
enable_nvidia_driver_autoinstall = true

##########################
# Disk Configuration
##########################
# RHEL 10 - manual CUDA installation required
# For Deep Learning VM (Ubuntu with pre-installed CUDA), use:
# boot_disk_image = "deeplearning-platform-release/common-cu129-ubuntu-2204-nvidia-580"
boot_disk_image = "rhel-cloud/rhel-10-0-eus"

# Larger disk for CUDA toolkit and development
boot_disk_size = 100 # GB

# SSD for better I/O performance
boot_disk_type = "pd-balanced"

##########################
# Network Configuration
##########################
# Use Cloud NAT for internet access
assign_external_ip = false

# Enable SSH access via IAP
enable_ssh_access = true

##########################
# Cost Optimization
##########################
# Use preemptible instance for 70% cost savings
# Perfect for development - just save your work frequently!
enable_preemptible = true

##########################
# Startup Script - Basic Setup
##########################
# Note: RHEL 10 - NVIDIA drivers auto-installed by GCP
# Install CUDA toolkit and Python packages manually after provisioning
startup_script = <<-EOF
#!/bin/bash
set -e

# Log all output
exec > >(tee /var/log/startup-script.log)
exec 2>&1

echo "=== RHEL 10 GPU Instance Setup ==="
echo "Timestamp: $(date)"

# Wait for NVIDIA driver installation (GCP auto-install)
echo "[1/3] Waiting for NVIDIA driver installation..."
max_wait=600
elapsed=0
while [ ! -f /usr/bin/nvidia-smi ]; do
    if [ $elapsed -ge $max_wait ]; then
        echo "WARNING: NVIDIA driver not found after $max_wait seconds"
        echo "Check: sudo systemctl status google-startup-scripts.service"
        break
    fi
    sleep 10
    elapsed=$((elapsed + 10))
done

# Verify NVIDIA driver if available
if [ -f /usr/bin/nvidia-smi ]; then
    echo "[2/3] Verifying NVIDIA driver..."
    nvidia-smi
    echo "NVIDIA Driver: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader)"
else
    echo "NVIDIA driver not yet installed. Wait a few minutes and check 'nvidia-smi'"
fi

# Install basic development tools
echo "[3/3] Installing development tools..."
dnf install -y \
    git \
    vim \
    tmux \
    htop \
    wget \
    gcc \
    gcc-c++ \
    make \
    kernel-devel-$(uname -r) \
    kernel-headers-$(uname -r)

echo "=== Basic Setup Complete ==="
echo ""
echo "Next Steps:"
echo "1. Verify GPU: nvidia-smi"
echo "2. Install CUDA Toolkit: https://developer.nvidia.com/cuda-downloads"
echo "3. Install Python 3.12 and GPU packages (cupy, numba, pycuda)"
echo ""
echo "Log file: /var/log/startup-script.log"
EOF

##########################
# Resource Labels
##########################
labels = {
  owner       = "devops"
  type        = "gpu-dev"
  workload    = "cuda-rhel-poc"
  os          = "rhel-10"
  cost_center = "engineering"
}

##########################
# Security Settings
##########################
deletion_protection = false
