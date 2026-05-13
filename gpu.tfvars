##########################
# GPU Environment Configuration
##########################
# Configuration for GPU-enabled instances for CUDA kernel development
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

# Automatically install NVIDIA drivers on boot
enable_nvidia_driver_autoinstall = true

##########################
# Disk Configuration
##########################
# Ubuntu 22.04 LTS (better CUDA support than Debian)
boot_disk_image = "ubuntu-os-cloud/ubuntu-2204-lts"

# Larger disk for CUDA toolkit, datasets, and development
boot_disk_size = 50 # GB

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
# Startup Script - CUDA Development Environment
##########################
startup_script = <<-EOF
#!/bin/bash
set -e

# Log all output
exec > >(tee /var/log/startup-script.log)
exec 2>&1

echo "=== Starting CUDA Development Environment Setup ==="
echo "Timestamp: $(date)"

# Update system
echo "[1/7] Updating system packages..."
apt-get update
apt-get upgrade -y

# Install development tools
echo "[2/7] Installing development tools..."
apt-get install -y \
  build-essential \
  git \
  wget \
  curl \
  vim \
  tmux \
  htop \
  nvtop \
  python3-pip \
  python3-dev

# Wait for NVIDIA driver installation (triggered by metadata)
echo "[3/7] Waiting for NVIDIA driver installation..."
max_wait=300  # 5 minutes timeout
elapsed=0
while ! nvidia-smi &>/dev/null; do
  if [ $elapsed -ge $max_wait ]; then
    echo "ERROR: NVIDIA driver installation timeout"
    exit 1
  fi
  echo "Waiting for NVIDIA drivers... ($elapsed seconds)"
  sleep 10
  elapsed=$((elapsed + 10))
done

echo "NVIDIA driver installed successfully!"
nvidia-smi

# Install CUDA Toolkit 12.3
echo "[4/7] Installing CUDA Toolkit 12.3..."
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i cuda-keyring_1.1-1_all.deb
apt-get update
apt-get install -y cuda-toolkit-12-3 cuda-drivers

# Set up CUDA environment variables
echo "[5/7] Configuring CUDA environment..."
cat >> /etc/profile.d/cuda.sh <<'CUDA_ENV'
export PATH=/usr/local/cuda-12.3/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-12.3/lib64:$LD_LIBRARY_PATH
export CUDA_HOME=/usr/local/cuda-12.3
CUDA_ENV

# Make it available immediately
source /etc/profile.d/cuda.sh

# Install Python packages for ML/CUDA development
echo "[6/7] Installing Python packages..."
pip3 install --upgrade pip
pip3 install \
  numpy \
  scipy \
  matplotlib \
  jupyter \
  jupyterlab \
  pandas \
  scikit-learn \
  torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 \
  tensorflow[and-cuda] \
  cupy-cuda12x \
  numba \
  pycuda

# Create CUDA samples directory
echo "[7/7] Setting up CUDA samples..."
mkdir -p /opt/cuda-samples
cd /opt/cuda-samples

# Create a simple CUDA test program
cat > /opt/cuda-samples/hello_cuda.cu <<'HELLO_CUDA'
#include <stdio.h>
#include <cuda_runtime.h>

__global__ void hello_from_gpu() {
    printf("Hello from GPU thread %d in block %d!\n", 
           threadIdx.x, blockIdx.x);
}

int main() {
    printf("=== CUDA Test Program ===\n");
    
    // Get GPU properties
    int device;
    cudaGetDevice(&device);
    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, device);
    
    printf("GPU: %s\n", prop.name);
    printf("Compute Capability: %d.%d\n", prop.major, prop.minor);
    printf("Total Global Memory: %.2f GB\n", 
           prop.totalGlobalMem / 1024.0 / 1024.0 / 1024.0);
    printf("Multiprocessors: %d\n", prop.multiProcessorCount);
    printf("\n");
    
    // Launch kernel
    hello_from_gpu<<<2, 4>>>();
    cudaDeviceSynchronize();
    
    printf("\nCUDA test completed successfully!\n");
    return 0;
}
HELLO_CUDA

# Compile the test program
/usr/local/cuda-12.3/bin/nvcc hello_cuda.cu -o hello_cuda

# Create a welcome README
cat > /opt/cuda-samples/README.md <<'README'
# CUDA Development Environment

## Quick Start

### Test CUDA Installation
```bash
# Check NVIDIA driver
nvidia-smi

# Run test program
cd /opt/cuda-samples
./hello_cuda

# Check CUDA version
nvcc --version
```

### Compile CUDA Programs
```bash
nvcc your_program.cu -o your_program
./your_program
```

### Python GPU Testing
```python
# PyTorch
import torch
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"GPU: {torch.cuda.get_device_name(0)}")

# TensorFlow
import tensorflow as tf
print(f"GPUs: {tf.config.list_physical_devices('GPU')}")

# CuPy
import cupy as cp
x = cp.array([1, 2, 3])
print(f"CuPy array on GPU: {x}")
```

### Start Jupyter Lab (for remote development)
```bash
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root
# Then use IAP tunnel: gcloud compute start-iap-tunnel INSTANCE_NAME 8888
```

## CUDA Samples Location
- CUDA Toolkit: `/usr/local/cuda-12.3/`
- Sample programs: `/opt/cuda-samples/`
- NVIDIA samples: `/usr/local/cuda-12.3/samples/`

## Monitor GPU Usage
```bash
# Real-time monitoring
nvidia-smi -l 1

# Or use nvtop (installed)
nvtop
```

## Cost Warning
This is a preemptible GPU instance (~$0.15/hour).
Save your work frequently as the instance may be terminated!
README

# Set permissions
chmod +x /opt/cuda-samples/hello_cuda
chmod 644 /opt/cuda-samples/README.md

# Print completion message
echo ""
echo "========================================="
echo "CUDA Development Environment Ready! 🚀"
echo "========================================="
echo ""
echo "GPU Information:"
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
echo ""
echo "CUDA Version:"
nvcc --version | grep "release"
echo ""
echo "Quick Start Guide: /opt/cuda-samples/README.md"
echo ""
echo "Test CUDA: cd /opt/cuda-samples && ./hello_cuda"
echo ""
echo "Log file: /var/log/startup-script.log"
echo "========================================="

# Mark setup as complete
touch /var/log/cuda-setup-complete
logger "CUDA development environment setup completed successfully"
EOF

##########################
# Resource Labels
##########################
labels = {
  owner       = "devops"
  type        = "gpu-dev"
  workload    = "cuda-development"
  cost_center = "engineering"
}

##########################
# Security Settings
##########################
deletion_protection = false
