##########################
# Project Configuration
##########################

variable "project_id" {
  description = "GCP project ID where compute resources will be created. This is the service project in a Shared VPC setup."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "network_project_id" {
  description = "GCP project ID where the Shared VPC network is hosted. This is the host project that owns the network resources."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.network_project_id))
    error_message = "Network project ID must be 6-30 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "project_name" {
  description = "Friendly project name used as a prefix for resource naming. Keep it short and lowercase."
  type        = string
  default     = "cts-sample"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,15}$", var.project_name))
    error_message = "Project name must be 3-16 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment identifier (dev, prod, or shared). Used for resource naming and tagging."
  type        = string

  validation {
    condition     = contains(["dev", "prod", "shared"], var.environment)
    error_message = "Environment must be one of: dev, prod, shared."
  }
}

variable "region" {
  description = "GCP region where resources will be created. Must match the network subnet region."
  type        = string
  default     = "us-central1"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.region))
    error_message = "Region must be a valid GCP region format (e.g., us-central1, europe-west1)."
  }
}

variable "zone" {
  description = "GCP zone for the compute instance. Must be within the specified region."
  type        = string
  default     = "us-central1-a"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+-[a-z]$", var.zone))
    error_message = "Zone must be a valid GCP zone format (e.g., us-central1-a, europe-west1-b)."
  }
}

##########################
# Network State Configuration
##########################

variable "network_state_bucket" {
  description = "GCS bucket name where the network module's Terraform state is stored. Used to retrieve VPC and subnet information."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-_.]{1,61}[a-z0-9]$", var.network_state_bucket))
    error_message = "Bucket name must be 3-63 characters, contain only lowercase letters, numbers, hyphens, underscores, and dots."
  }
}

variable "network_state_prefix" {
  description = "Path prefix in the GCS bucket where the network state file is located (e.g., 'network/vpc/dev')."
  type        = string
  default     = "network/vpc/dev"

  validation {
    condition     = can(regex("^[a-zA-Z0-9/_-]+$", var.network_state_prefix))
    error_message = "State prefix must contain only alphanumeric characters, slashes, hyphens, and underscores."
  }
}

##########################
# Compute Instance Configuration
##########################

variable "machine_type" {
  description = "GCE machine type. Use e2-micro for free tier eligibility. See: https://cloud.google.com/compute/docs/machine-types"
  type        = string
  default     = "e2-micro"

  validation {
    condition     = can(regex("^[a-z][0-9]+-", var.machine_type))
    error_message = "Machine type must be a valid GCE machine type format (e.g., e2-micro, n2-standard-2)."
  }
}

variable "boot_disk_image" {
  description = "Boot disk image in the format 'project/image-family' or 'project/image-name'. Examples: debian-cloud/debian-12, ubuntu-os-cloud/ubuntu-2204-lts"
  type        = string
  default     = "debian-cloud/debian-12"

  validation {
    condition     = can(regex("^[a-z0-9-]+/[a-z0-9-]+$", var.boot_disk_image))
    error_message = "Boot disk image must be in format 'project/image' (e.g., debian-cloud/debian-12)."
  }
}

variable "boot_disk_size" {
  description = "Boot disk size in GB. Free tier allows up to 30 GB of standard persistent disk per month."
  type        = number
  default     = 10

  validation {
    condition     = var.boot_disk_size >= 10 && var.boot_disk_size <= 65536
    error_message = "Boot disk size must be between 10 GB (minimum) and 65536 GB (64 TB maximum)."
  }
}

variable "boot_disk_type" {
  description = "Boot disk type. Use 'pd-standard' for free tier. Options: pd-standard, pd-balanced, pd-ssd"
  type        = string
  default     = "pd-standard"

  validation {
    condition     = contains(["pd-standard", "pd-balanced", "pd-ssd", "pd-extreme"], var.boot_disk_type)
    error_message = "Boot disk type must be one of: pd-standard, pd-balanced, pd-ssd, pd-extreme."
  }
}

variable "assign_external_ip" {
  description = "Whether to assign an ephemeral external IP to the instance. Set to false to use Cloud NAT for internet access (recommended)."
  type        = bool
  default     = false
}

variable "enable_ssh_access" {
  description = "Whether to add network tags for SSH access via Identity-Aware Proxy (IAP). Requires appropriate firewall rules."
  type        = bool
  default     = true
}

##########################
# GPU Configuration
##########################

variable "enable_gpu" {
  description = "Whether to attach a GPU to the instance. Requires GPU-compatible machine types (n1-standard-*, a2-*, etc.)."
  type        = bool
  default     = false
}

variable "gpu_type" {
  description = "Type of GPU to attach. Common options: nvidia-tesla-t4 (cheapest), nvidia-tesla-v100, nvidia-tesla-a100, nvidia-l4"
  type        = string
  default     = "nvidia-tesla-t4"

  validation {
    condition     = can(regex("^nvidia-", var.gpu_type))
    error_message = "GPU type must start with 'nvidia-' (e.g., nvidia-tesla-t4, nvidia-tesla-v100)."
  }
}

variable "gpu_count" {
  description = "Number of GPUs to attach (1-8 depending on machine type). T4 supports 1-4, V100 supports 1-8, A100 supports 1-16."
  type        = number
  default     = 1

  validation {
    condition     = var.gpu_count >= 1 && var.gpu_count <= 16
    error_message = "GPU count must be between 1 and 16."
  }
}

variable "enable_nvidia_driver_autoinstall" {
  description = "Automatically install NVIDIA GPU drivers on instance boot. Set to true for GPU instances."
  type        = bool
  default     = false
}

##########################
# Service Account Configuration
##########################

variable "service_account_email" {
  description = "Service account email to attach to the instance. Leave empty to use the default Compute Engine service account."
  type        = string
  default     = ""

  validation {
    condition     = var.service_account_email == "" || can(regex("^[a-z][a-z0-9-]{4,28}@[a-z0-9-]+\\.iam\\.gserviceaccount\\.com$", var.service_account_email))
    error_message = "Service account email must be empty or a valid GCP service account email format."
  }
}

variable "service_account_scopes" {
  description = "OAuth scopes for the service account. Use 'cloud-platform' for full access, or specify granular scopes for least privilege."
  type        = list(string)
  default = [
    "https://www.googleapis.com/auth/cloud-platform"
  ]

  validation {
    condition     = length(var.service_account_scopes) > 0
    error_message = "At least one service account scope must be specified."
  }
}

##########################
# Network Configuration
##########################

variable "network_tags" {
  description = "Additional network tags for the instance. Used by firewall rules to control traffic. Base tags are automatically added."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for tag in var.network_tags : can(regex("^[a-z][a-z0-9-]{0,62}$", tag))])
    error_message = "Network tags must start with a lowercase letter and contain only lowercase letters, numbers, and hyphens (max 63 chars)."
  }
}

##########################
# Optional Configuration
##########################

variable "metadata" {
  description = "Custom metadata key-value pairs to attach to the instance. Useful for startup scripts, configuration data, etc."
  type        = map(string)
  default     = {}
}

variable "startup_script" {
  description = "Shell script to run when the instance boots. Use for initial configuration, software installation, etc."
  type        = string
  default     = ""
}

variable "labels" {
  description = "Additional labels to apply to the instance. Labels are key-value pairs for organizing and filtering resources."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for key, value in var.labels :
      can(regex("^[a-z][a-z0-9_-]{0,62}$", key)) &&
      can(regex("^[a-z0-9_-]{0,63}$", value))
    ])
    error_message = "Label keys and values must contain only lowercase letters, numbers, hyphens, and underscores. Keys must start with a letter."
  }
}

variable "deletion_protection" {
  description = "Enable deletion protection to prevent accidental instance deletion. Recommended for production environments."
  type        = bool
  default     = false
}

variable "enable_preemptible" {
  description = "Create instance as preemptible (spot) for 70-80% cost savings. Instance may be terminated at any time. Great for development/testing."
  type        = bool
  default     = false
}
