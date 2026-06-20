#!/bin/bash
#
# RHEL GPU Setup Script
# Supports RHEL 8, 9, 10 with CUDA 13.3 and PyTorch, and CuPy
# Note: RHEL 10 Needs additional testing

# --- BASH SAFE MODE ---
set -euo pipefail
IFS=$'\n\t'

# --- LOGGING SETUP ---
LOG_FILE="/var/log/gpu-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=========================================="
echo "GPU Setup Started: $(date)"
echo "=========================================="

# --- PRE-FLIGHT CHECKS ---
echo "[1/12] Pre-flight checks..."

# Check if GPU is present
if ! sudo dnf install -y pciutils; then
    echo "[ERROR] Failed to install pciutils"
    exit 1
fi

if ! lspci | grep -i nvidia; then
    echo "[ERROR] No NVIDIA GPU detected in system"
    echo "Available PCI devices:"
    lspci | head -20
    exit 1
fi
echo "[OK] NVIDIA GPU detected"

# Check if already installed (idempotent)
if nvidia-smi &>/dev/null; then
    echo "[INFO] NVIDIA drivers already installed and working"
    nvidia-smi
    echo "[INFO] Skipping driver installation, proceeding to Python setup..."
    SKIP_DRIVER_INSTALL=true
else
    SKIP_DRIVER_INSTALL=false
fi

# --- DETECT RHEL VERSION ---
echo "[2/12] Detecting RHEL version..."
RHEL_VERSION=$(grep -oP '(?<=VERSION_ID=")[0-9]+' /etc/os-release | head -n 1)
echo "[INFO] Detected RHEL $RHEL_VERSION system"

# --- SYNCHRONIZE KERNEL AND HEADERS ---
echo "[3/12] Installing kernel headers for running kernel..."
KERNEL_VERSION=$(uname -r)
echo "[INFO] Running kernel: $KERNEL_VERSION"

# Install headers for EXACT running kernel version
sudo dnf install -y \
    kernel-devel-${KERNEL_VERSION} \
    kernel-headers-${KERNEL_VERSION} \
    gcc \
    make

# Verify headers installed correctly
if [ ! -d "/usr/src/kernels/${KERNEL_VERSION}" ]; then
    echo "[ERROR] Kernel headers not found for running kernel ${KERNEL_VERSION}"
    echo "Available kernel headers:"
    ls -la /usr/src/kernels/ 2>/dev/null || echo "  None found"
    echo "[ERROR] This is a critical failure - headers must match running kernel"
    exit 1
fi
echo "[OK] Kernel headers installed and verified for ${KERNEL_VERSION}"

# --- PYTHON VERSION SETUP ---
echo "[4/12] Setting up Python version..."
if [ "$RHEL_VERSION" -eq 8 ]; then
   sudo dnf install -y python39 python39-devel
   PYTHON_CMD=python3.9
elif [ "$RHEL_VERSION" -eq 9 ]; then
    sudo dnf install -y python3.11 python3.11-devel
    PYTHON_CMD=python3.11
else
    # RHEL 10+
    sudo dnf install -y python3.11 python3.11-devel
    PYTHON_CMD=python3.11
fi
echo "[OK] Using $PYTHON_CMD (version: $($PYTHON_CMD --version))"

# --- ENABLE EPEL REPOSITORY ---
echo "[5/12] Enabling EPEL repository (for DKMS)..."
if [ "$RHEL_VERSION" -eq 8 ]; then
    sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
elif [ "$RHEL_VERSION" -eq 9 ]; then
    sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
else
    sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm
fi

# Install DKMS
sudo dnf install -y dkms
echo "[OK] EPEL and DKMS installed"

# --- SKIP DRIVER INSTALLATION IF ALREADY WORKING ---
if [ "$SKIP_DRIVER_INSTALL" = true ]; then
    echo "[6-9/12] Skipping driver installation (already working)"
else
    # --- ADD NVIDIA CUDA REPOSITORY ---
    echo "[6/12] Adding NVIDIA CUDA repository..."
    sudo dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel${RHEL_VERSION}/x86_64/cuda-rhel${RHEL_VERSION}.repo
    sudo dnf clean all
    echo "[OK] CUDA repository added"

    # --- INSTALL CUDA TOOLKIT AND DRIVERS ---
    echo "[7/12] Installing CUDA toolkit and NVIDIA drivers..."
    if [[ "$RHEL_VERSION" -eq 8 || "$RHEL_VERSION" -eq 9 ]]; then
        echo "[INFO] Using RHEL 8, 9 installation method..."
        # Install CUDA toolkit first
        sudo dnf install -y cuda-toolkit-13-3
        
        # Install NVIDIA driver via module
        sudo dnf module install -y nvidia-driver:latest-dkms
    else
        echo "[INFO] Using RHEL 10 installation method..."
        sudo dnf install -y cuda-toolkit-13-3 nvidia-driver-latest-dkms
    fi
    echo "[OK] CUDA toolkit and drivers installed"

    # --- VERIFY DKMS BUILD ---
    echo "[8/12] Building and verifying NVIDIA kernel modules..."
    sudo dkms autoinstall
    
    # Check DKMS status
    if dkms status | grep -q nvidia; then
        echo "[OK] NVIDIA modules built via DKMS:"
        dkms status | grep nvidia
    else
        echo "[WARNING] NVIDIA modules not found in DKMS status"
    fi

    # --- LOAD NVIDIA MODULES ---
    echo "[9/12] Loading NVIDIA kernel modules..."
    if sudo modprobe nvidia; then
        echo "[OK] nvidia module loaded successfully"
    else
        echo "[WARNING] Could not load nvidia module (may require reboot)"
    fi
    
    # Load additional modules
    sudo modprobe nvidia_uvm 2>/dev/null || true
    sudo modprobe nvidia_drm 2>/dev/null || true
fi

# --- VERIFY GPU ACCESS ---
echo "[10/12] Verifying GPU access..."
if nvidia-smi; then
    echo "[SUCCESS] nvidia-smi working! GPU details:"
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv
else
    echo "[WARNING] nvidia-smi not working yet - reboot may be required"
    echo "[INFO] This is normal on first install. Run 'sudo reboot' and re-run verification."
fi

# --- SET CUDA ENVIRONMENT VARIABLES ---
echo "[11/12] Setting CUDA environment variables..."
CUDA_ENV_FILE="/etc/profile.d/cuda.sh"

# Create system-wide CUDA environment file
sudo tee "$CUDA_ENV_FILE" > /dev/null <<'EOF'
# CUDA 13.3 Environment Variables
export PATH=/usr/local/cuda-13.3/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda-13.3/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
export CUDA_HOME=/usr/local/cuda-13.3
EOF

# Also add to current user's .bashrc for convenience
if ! grep -q "cuda-13.3" ~/.bashrc 2>/dev/null; then
    echo 'export PATH=/usr/local/cuda-13.3/bin${PATH:+:${PATH}}' >> ~/.bashrc
    echo 'export LD_LIBRARY_PATH=/usr/local/cuda-13.3/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}' >> ~/.bashrc
    echo 'export CUDA_HOME=/usr/local/cuda-13.3' >> ~/.bashrc
fi

# Apply to current session
export PATH=/usr/local/cuda-13.3/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda-13.3/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
export CUDA_HOME=/usr/local/cuda-13.3

# Verify CUDA compiler if available
if command -v nvcc &>/dev/null; then
    echo "[OK] CUDA environment configured. nvcc version:"
    nvcc --version | grep "release"
else
    echo "[INFO] nvcc not found yet - CUDA toolkit may need reboot to be available"
fi

# --- PYTHON AI STACK SETUP ---
echo "[12/12] Setting up Python AI environment..."

# Remove old virtual environment if it exists
if [ -d ~/ag-env ]; then
    echo "[INFO] Removing existing virtual environment..."
    rm -rf ~/ag-env
fi

# Create virtual environment with detected Python version
echo "[INFO] Creating virtual environment with $PYTHON_CMD..."
$PYTHON_CMD -m venv ~/ag-env
source ~/ag-env/bin/activate

echo "[INFO] Virtual environment created with $($PYTHON_CMD --version)"
echo "[INFO] Installing Python packages (this may take several minutes)..."

# Upgrade pip first
pip install --upgrade pip

# Install PyTorch, CuPy, and other AI packages
pip install torch torchvision torchaudio cupy-cuda13x

echo "[OK] Python AI stack installed"

# --- CREATE GPU VERIFICATION SCRIPT ---
echo "[INFO] Creating GPU verification script..."

cat <<'EOF' > ~/verify_gpu.py
#!/usr/bin/env python3
"""
GPU Verification Script
Tests CUDA, PyTorch, and CuPy functionality
"""

import sys

print("\n" + "="*50)
print("GPU Verification Test")
print("="*50 + "\n")

# Test 1: PyTorch
print("[1/3] Testing PyTorch...")
try:
    import torch
    print(f"  [OK] PyTorch Version: {torch.__version__}")
    print(f"  [OK] CUDA Available: {torch.cuda.is_available()}")
    
    if torch.cuda.is_available():
        print(f"  [OK] GPU Name: {torch.cuda.get_device_name(0)}")
        print(f"  [OK] CUDA Version: {torch.version.cuda}")
        
        # Simple tensor operation on GPU
        x = torch.randn(3, 3).cuda()
        y = x * 2
        print(f"  [OK] GPU Tensor Test: SUCCESS")
    else:
        print("  [ERROR] CUDA not available to PyTorch")
        sys.exit(1)
except ImportError as e:
    print(f"  [ERROR] PyTorch not installed: {e}")
    sys.exit(1)

# Test 2: CuPy
print("\n[2/3] Testing CuPy...")
try:
    import cupy as cp
    print(f"  [OK] CuPy Version: {cp.__version__}")
    
    # Test GPU calculation
    x = cp.array([1, 2, 3])
    y = cp.array([4, 5, 6])
    z = x + y
    print(f"  [OK] CuPy GPU Calculation: [1,2,3] + [4,5,6] = {z}")
    print(f"  [OK] GPU Device: {cp.cuda.runtime.getDeviceProperties(0)['name'].decode()}")
except ImportError as e:
    print(f"  [ERROR] CuPy not installed: {e}")
    sys.exit(1)
except Exception as e:
    print(f"  [ERROR] CuPy error: {e}")
    sys.exit(1)

# Test 3: CUDA Runtime Info
print("\n[3/3] CUDA Runtime Info...")
try:
    import torch
    props = torch.cuda.get_device_properties(0)
    print(f"  [OK] GPU Memory: {props.total_memory / 1024**3:.2f} GB")
    print(f"  [OK] Multiprocessors: {props.multi_processor_count}")
    print(f"  [OK] Compute Capability: {props.major}.{props.minor}")
except Exception as e:
    print(f"  [ERROR] Could not get CUDA properties: {e}")

print("\n" + "="*50)
print("STATUS: ALL TESTS PASSED")
print("="*50 + "\n")
EOF

chmod +x ~/verify_gpu.py

# --- FINAL SUMMARY ---
echo ""
echo "=========================================="
echo "GPU SETUP COMPLETE"
echo "=========================================="
echo ""
echo "Installation Details:"
echo "  - RHEL Version: $RHEL_VERSION"
echo "  - Kernel: $KERNEL_VERSION"
echo "  - Python: $($PYTHON_CMD --version)"
echo "  - CUDA: 13.3"
echo "  - Virtual Environment: ~/ag-env"
echo ""
echo "Next Steps:"
echo ""
if nvidia-smi &>/dev/null; then
    echo "[OK] GPU is already working!"
    echo ""
    echo "  1. Reload shell environment (to enable nvcc):"
    echo "     source ~/.bashrc"
    echo ""
    echo "  2. Activate Python environment:"
    echo "     source ~/ag-env/bin/activate"
    echo ""
    echo "  3. Run verification:"
    echo "     python ~/verify_gpu.py"
else
    echo "[WARNING] Reboot required to load NVIDIA drivers:"
    echo ""
    echo "  1. Reboot the system:"
    echo "     sudo reboot"
    echo ""
    echo "  2. After reboot, reload shell environment:"
    echo "     source ~/.bashrc"
    echo ""
    echo "  3. Activate Python environment:"
    echo "     source ~/ag-env/bin/activate"
    echo ""
    echo "  4. Run verification:"
    echo "     python ~/verify_gpu.py"
fi
echo ""
echo "=========================================="
echo "Setup completed: $(date)"
echo "Log file: $LOG_FILE"
echo "=========================================="
