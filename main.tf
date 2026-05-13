##########################
# Data Source - Remote State
##########################
# Retrieve network configuration from the network module's Terraform state
# This enables secure integration with Shared VPC without hardcoding network details
#
# The network module must output:
#   - vpc_name: Name of the VPC network
#   - app_subnet_name: Name of the application tier subnet

data "terraform_remote_state" "network" {
  backend = "gcs"

  config = {
    bucket = var.network_state_bucket
    prefix = var.network_state_prefix
  }
}

##########################
# Compute Instance
##########################
# Creates a compute instance in a Shared VPC environment
#
# Security features:
#   - OS Login enabled for centralized SSH key management
#   - Project-wide SSH keys blocked
#   - Optional external IP (default: private only via Cloud NAT)
#   - Network tags for firewall rule targeting
#
# Shared VPC integration:
#   - Network resources in separate host project
#   - Service account from service project
#   - Proper cross-project IAM permissions required

resource "google_compute_instance" "app_vm" {
  # Instance identification
  name    = "${local.resource_prefix}-app-vm"
  project = var.project_id

  # Compute resources
  machine_type = var.machine_type
  zone         = var.zone

  # Boot disk configuration
  boot_disk {
    initialize_params {
      image = var.boot_disk_image
      size  = var.boot_disk_size
      type  = var.boot_disk_type
    }

    # Auto-delete boot disk when instance is deleted
    auto_delete = true
  }

  # Network configuration for Shared VPC
  # Network and subnet must be specified as full paths since they're in a different project
  network_interface {
    # Full path to network in host project
    network = local.network_self_link

    # Full path to subnet in host project (regional resource)
    subnetwork = local.subnet_self_link

    # External IP configuration
    # If disabled, use Cloud NAT for internet access (recommended)
    dynamic "access_config" {
      for_each = var.assign_external_ip ? [1] : []
      content {
        # Ephemeral public IP will be automatically assigned
        # For static IP, add: nat_ip = google_compute_address.static.address
      }
    }
  }

  # GPU configuration
  # Attach GPU accelerators for machine learning, CUDA development, etc.
  # Note: Requires compatible machine type (n1-standard-*, a2-*, g2-standard-*, etc.)
  dynamic "guest_accelerator" {
    for_each = var.enable_gpu ? [1] : []
    content {
      type  = var.gpu_type
      count = var.gpu_count
    }
  }

  # GPU-specific scheduling configuration
  # on_host_maintenance must be TERMINATE for GPU instances
  # automatic_restart must be false for preemptible instances
  scheduling {
    on_host_maintenance = var.enable_gpu ? "TERMINATE" : "MIGRATE"
    automatic_restart   = !var.enable_preemptible # Preemptible instances cannot auto-restart
    preemptible         = var.enable_preemptible
  }

  # Network tags for firewall rule targeting
  # Tags determine which firewall rules apply to this instance
  tags = local.network_tags

  # Instance metadata
  # Metadata is available to the instance via the metadata server
  # For GPU instances, add install-nvidia-driver metadata
  metadata = var.enable_nvidia_driver_autoinstall ? merge(
    local.default_metadata,
    {
      "install-nvidia-driver" = "True"
    }
  ) : local.default_metadata

  # Startup script runs on instance boot and every restart
  # Use for initial configuration, software installation, etc.
  metadata_startup_script = var.startup_script != "" ? var.startup_script : null

  # Service account and access scopes
  # Determines what GCP APIs the instance can access
  service_account {
    # Use custom service account or fall back to default Compute Engine SA
    email = var.service_account_email != "" ? var.service_account_email : null

    # OAuth scopes define API access permissions
    scopes = var.service_account_scopes
  }

  # Resource labels for organization and billing attribution
  # Labels are queryable via GCP APIs and visible in the console
  labels = local.common_labels

  # Lifecycle configuration
  # Allow Terraform to stop the instance for updates that require it
  allow_stopping_for_update = true

  # Deletion protection prevents accidental instance deletion
  # Recommended for production environments
  deletion_protection = var.deletion_protection

  # Ensure network resources exist before creating instance
  depends_on = [
    data.terraform_remote_state.network
  ]
}
