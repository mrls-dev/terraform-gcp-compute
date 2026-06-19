#!/bin/bash

# --- BASH SAFE MODE ---
set -euo pipefail
IFS=$'\n\t'

# 1. Detect RHEL Version
RHEL_VERSION=$(grep -oP '(?<=VERSION_ID=")[0-9]+' /etc/os-release | head -n 1)
echo "[INFO] Detected RHEL $RHEL_VERSION system."

# 2. Synchronize Kernel and Headers
echo "[INFO] Syncing Kernel and Headers..."
sudo dnf update -y kernel
sudo dnf install -y kernel-devel-$(uname -r) kernel-headers-$(uname -r) gcc make

# 3. Enable EPEL (for DKMS)
echo "[INFO] Enabling EPEL Repository..."
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

echo "[INFO] Using $PYTHON_CMD (version: $($PYTHON_CMD --version))"

echo "[INFO] Enabling EPEL Repository..."
if [ "$RHEL_VERSION" -eq 8 ]; then
    sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
else
    sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm
fi


# 4. Add NVIDIA CUDA Repo
echo "[INFO] Adding NVIDIA CUDA Repo..."
sudo dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel${RHEL_VERSION}/x86_64/cuda-rhel${RHEL_VERSION}.repo

# 5. Disable Broken GCP/RHUI Repos
# echo "[INFO] Disabling problematic RHUI repos..."
# sudo dnf config-manager --set-disabled "rhui-codeready-builder*" "rhui-*-debug-rpms" "rhui-*-source-rpms"

# 6. Install Logic (RHEL 8 vs 10)
if [ "$RHEL_VERSION" -eq 8 ]; then
    echo "[INFO] Applying RHEL 8 Modularity Fixes..."
    sudo dnf install -y cuda-toolkit-13-3
    sudo dnf module install -y nvidia-driver:latest-dkms \
    # --disablerepo="rhui-codeready-builder*" \
    # --disablerepo="rhui-*-debug-rpms" \
    # --disablerepo="rhui-*-source-rpms"

else
    echo "[INFO] Performing Seamless RHEL 10 Install..."
    sudo dnf install -y cuda-toolkit-13-3 nvidia-driver-latest-dkms --disablerepo="rhui-*"
fi

# 7. Finalize and Force DKMS Build
echo "[INFO] Finalizing Driver Build..."
sudo dkms autoinstall

# 8. Set Environment Variables
echo "[INFO] Setting Environment Variables..."
if ! grep -q "cuda-13.3" ~/.bashrc; then
    echo 'export PATH=/usr/local/cuda-13.3/bin${PATH:+:${PATH}}' >> ~/.bashrc
    echo 'export LD_LIBRARY_PATH=/usr/local/cuda-13.3/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}' >> ~/.bashrc
fi
# Apply to current session
export PATH=/usr/local/cuda-13.3/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda-13.3/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}

# 9. --- PYTHON AI STACK SETUP ---
echo "[INFO] Setting up Python Ag-Tech AI Environment..."

# Remove old virtual environment if it exists (may be using wrong Python version)
if [ -d ~/ag-env ]; then
    echo "[WARN] Removing existing virtual environment (may contain incompatible Python version)..."
    rm -rf ~/ag-env
fi

$PYTHON_CMD -m venv ~/ag-env
source ~/ag-env/bin/activate
echo "[INFO] Virtual environment created with $($PYTHON_CMD --version)"
pip install --upgrade pip
pip install torch torchvision torchaudio cupy-cuda12x

# 10. --- PYTHON HEARTBEAT TEST ---
echo "[INFO] Creating Python GPU Verification Script..."

cat <<EOF > verify_gpu.py
import torch
import cupy as cp

print("\n--- Ag-Tech AI Heartbeat ---")
print(f"PyTorch Version: {torch.__version__}")
print(f"CUDA Available: {torch.cuda.is_available()}")

if torch.cuda.is_available():
    print(f"GPU Name: {torch.cuda.get_device_name(0)}")
    # Test a simple GPU calculation with CuPy
    x = cp.array([1, 2, 3])
    y = cp.array([4, 5, 6])
    z = x + y
    print(f"CuPy GPU Calculation Test (1,2,3 + 4,5,6): {z}")
    print("--- STATUS: SUCCESS ---")
else:
    print("--- STATUS: GPU NOT DETECTED (Reboot Required) ---")
EOF

echo "------------------------------------------------"
echo "INSTALLATION COMPLETE"
echo "1. Run: sudo reboot"
echo "2. After reboot, run: source ~/ag-env/bin/activate"
echo "3. Run: python verify_gpu.py"
echo "------------------------------------------------"
