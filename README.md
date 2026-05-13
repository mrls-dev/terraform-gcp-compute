# GCP GPU Compute Infrastructure - Terraform Module

Production-ready Terraform module for deploying GPU-enabled compute instances on Google Cloud Platform for CUDA kernel development and machine learning workloads.

## Overview

This module creates a GPU-enabled compute instance with NVIDIA Tesla T4 GPU, pre-configured with CUDA toolkit, PyTorch, TensorFlow, and Jupyter Lab for interactive development.

## Features

- **GPU-Enabled**: NVIDIA Tesla T4 (16GB VRAM, 2560 CUDA cores)
- **CUDA Toolkit**: Pre-installed CUDA 12.3 with samples
- **ML Frameworks**: PyTorch, TensorFlow, CuPy, PyCUDA, Numba
- **Jupyter Lab**: Interactive development environment with GPU access
- **Cost-Optimized**: Preemptible instances (~70% savings, ~$0.15/hour)
- **Shared VPC**: Network isolation with service/host project architecture
- **CI/CD Ready**: GitHub Actions with Workload Identity Federation
- **Infrastructure as Code**: Comprehensive validation, linting, and documentation


## Prerequisites

1. **Network Infrastructure**: Shared VPC deployed in `mrls-dev-network` project
   - See [SHARED-VPC-SETUP.md](SHARED-VPC-SETUP.md)
2. **GCS Backend**: Terraform state bucket configured
3. **IAM Permissions**:
   - On service project: `roles/compute.instanceAdmin.v1`, `roles/iam.serviceAccountUser`
   - On host project: `roles/compute.networkUser`
4. **GPU Quota**: NVIDIA T4 GPUs enabled in your region

## Quick Start

### Option 1: GitHub Actions

Automated deployment via GitHub Actions with Workload Identity Federation (keyless authentication).

**Quick summary:**
1. Configure Workload Identity Federation
2. Update `.github/workflows/terraform-dev.yml` with your repo
3. Push to GitHub - automatic deployment!

### Option 2: Local Deployment

For testing and development:

```bash
# 1. Initialize Terraform
terraform init -backend-config=backend-gpu.hcl

# 2. Review the plan
terraform plan -var-file=gpu.tfvars

# 3. Deploy
terraform apply -var-file=gpu.tfvars

# 4. Get SSH command
terraform output ssh_command

# 5. Destroy when done (stop GPU costs!)
terraform destroy -var-file=gpu.tfvars
```

## Usage Examples

### Basic GPU Development

Deploy a GPU instance for CUDA development:

```hcl
# gpu.tfvars
project_id         = "your-compute-project"
network_project_id = "your-network-project"
project_name       = "cuda-dev"
environment        = "gpu"
region             = "us-central1"
zone               = "us-central1-a"

machine_type       = "n1-standard-4"
enable_gpu         = true
gpu_type           = "nvidia-tesla-t4"
gpu_count          = 1
enable_preemptible = true  # Save 70% on costs!

boot_disk_image    = "ubuntu-os-cloud/ubuntu-2204-lts"
boot_disk_size     = 50

network_state_bucket = "your-terraform-state-bucket"
network_state_prefix = "network/vpc/dev"
```

### Access and Test

```bash
# SSH into instance
gcloud compute ssh cuda-dev-gpu-app-vm --zone=us-central1-a \
  --tunnel-through-iap --project=your-compute-project

# Verify GPU
nvidia-smi

# Test CUDA
cd /opt/cuda-samples && ./hello_cuda

# Start Jupyter Lab (on instance)
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser

# Create SSH tunnel (on local machine)
gcloud compute ssh cuda-dev-gpu-app-vm --zone=us-central1-a \
  --tunnel-through-iap --project=your-compute-project \
  -- -L 8888:localhost:8888
```

## CUDA Development Workflow

1. **Deploy instance**: `terraform apply -var-file=gpu.tfvars`
2. **SSH access**: Use output command from `terraform output ssh_command`
3. **Verify GPU**: Run `nvidia-smi` to check GPU status
4. **Test CUDA**: Run sample programs in `/opt/cuda-samples/`
5. **Develop**: Use Jupyter Lab with PyTorch/TensorFlow
6. **Monitor**: `watch -n 1 nvidia-smi` for real-time GPU usage
7. **Destroy**: `terraform destroy` when done to stop costs

## Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `project_id` | GCP service project ID | `project-70f3c2b9-8f91-41f7-b5c` |
| `network_project_id` | GCP network host project ID | `mrls-dev-network` |
| `project_name` | Resource naming prefix | `cuda-dev` |
| `environment` | Environment identifier | `gpu` |
| `region` | GCP region | `us-central1` |
| `zone` | GCP zone | `us-central1-a` |
| `network_state_bucket` | GCS bucket for network state | `org-terraform-state-dev` |
| `network_state_prefix` | State prefix path | `network/vpc/dev` |

### GPU Configuration

| Variable | Description | Default | Options |
|----------|-------------|---------|---------|
| `enable_gpu` | Enable GPU attachment | `true` | `true`, `false` |
| `gpu_type` | GPU accelerator type | `nvidia-tesla-t4` | `nvidia-tesla-t4`, `nvidia-tesla-k80`, `nvidia-tesla-p4`, `nvidia-tesla-p100` |
| `gpu_count` | Number of GPUs | `1` | `1-8` (depends on machine type) |
| `enable_nvidia_driver_autoinstall` | Auto-install NVIDIA drivers | `true` | `true`, `false` |
| `enable_preemptible` | Use preemptible instances | `true` | `true`, `false` |

### Machine Types

GPU-compatible machine types:
- `n1-standard-4`: 4 vCPU, 15GB RAM (recommended for single GPU)
- `n1-standard-8`: 8 vCPU, 30GB RAM
- `n1-highmem-4`: 4 vCPU, 26GB RAM
- `n1-highmem-8`: 8 vCPU, 52GB RAM

Full list: [GCP Machine Types](https://cloud.google.com/compute/docs/gpus)

## Project Structure

```
.
├── main.tf                  # Core compute instance resource
├── variables.tf             # Input variable definitions with validation
├── outputs.tf               # Output values (SSH commands, instance info)
├── providers.tf             # Google Cloud provider configuration
├── versions.tf              # Terraform version constraints
├── backend.tf               # GCS backend configuration
├── locals.tf                # Computed values and constants
├── gpu.tfvars               # GPU instance configuration
├── backend-gpu.hcl          # Backend config for GPU environment
├── .gitignore               # Security: prevent sensitive file commits
├── Makefile                 # Convenient shortcuts
├── .tflint.hcl              # Linting configuration
├── .editorconfig            # Code formatting rules
├── .pre-commit-config.yaml  # Pre-commit hooks
├── SHARED-VPC-SETUP.md      # Network configuration guide
└── .github/
    └── workflows/
        └── terraform-dev.yml # GitHub Actions workflow
```

## Development Tools

### Makefile Commands

```bash
make init ENV=gpu      # Initialize with GPU backend
make plan ENV=gpu      # Plan changes
make apply ENV=gpu     # Apply changes
make destroy ENV=gpu   # Destroy resources
make validate          # Validate configuration
make fmt               # Format code
make lint              # Run tflint
make ssh ENV=gpu       # SSH into instance
make output ENV=gpu    # Show outputs
```

### Pre-commit Hooks

Install for automatic code quality checks:

```bash
pre-commit install
```

Runs on every commit:
- Terraform formatting
- Validation
- Documentation generation
- Security scanning (tfsec)

