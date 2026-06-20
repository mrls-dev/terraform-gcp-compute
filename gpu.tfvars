##########################
# GPU Environment Configuration
##########################
# Configuration for GPU-enabled instances for CUDA kernel development
# Uses Google Deep Learning VM with pre-installed NVIDIA drivers and CUDA
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
# RHEL 9 - requires manual CUDA installation after driver setup
boot_disk_image = "rhel-cloud/rhel-9"

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
# Startup Script - CUDA Development Environment
##########################
# Note: Deep Learning VM comes with NVIDIA drivers, CUDA 12.9, and Python 3.12 pre-installed
startup_script = <<-EOF
#!/bin/bash
set -e

# Log all output
exec > >(tee /var/log/startup-script.log)
exec 2>&1

echo "=== Deep Learning VM Setup ==="
echo "Timestamp: $(date)"

# Verify NVIDIA drivers and CUDA are working
echo "[1/4] Verifying GPU setup..."
nvidia-smi
nvcc --version

# Install additional development tools
echo "[2/4] Installing additional tools..."
apt-get update
apt-get install -y \
  git \
  vim \
  tmux \
  htop \
  nvtop

# Install additional Python packages for CUDA development
echo "[3/4] Installing Python packages..."
pip3 install --upgrade pip
pip3 install \
  jupyterlab \
  cupy-cuda12x \
  numba \
  pycuda

# Create CUDA samples directory
echo "[4/4] Setting up CUDA samples..."
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
nvcc hello_cuda.cu -o hello_cuda

# Create a welcome README
cat > /opt/cuda-samples/README.md <<'README'
# CUDA Development Environment
# Google Deep Learning VM - Ubuntu 22.04, CUDA 12.9, Python 3.12

## Pre-installed Software
- NVIDIA Driver 580
- CUDA Toolkit 12.9
- cuDNN
- PyTorch (with CUDA support)
- TensorFlow (with CUDA support)
- Python 3.12

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
# Then use IAP tunnel from your local machine:
# gcloud compute start-iap-tunnel INSTANCE_NAME 8888 --local-host-port=localhost:8888
```

## Resources
- [CUDA Programming Guide](https://docs.nvidia.com/cuda/cuda-c-programming-guide/)
- [PyTorch CUDA Semantics](https://pytorch.org/docs/stable/notes/cuda.html)
- [TensorFlow GPU Guide](https://www.tensorflow.org/guide/gpu)
README

echo "=== Setup Complete! ==="
echo ""
echo "GPU Information:"
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv
echo ""
echo "CUDA Version:"
nvcc --version | grep "release"
echo ""
echo "Python Version:"
python3 --version
echo ""
echo "Ready for CUDA development!"
echo "Check /opt/cuda-samples/README.md for usage instructions"
echo ""
echo "Log file: /var/log/startup-script.log"
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
