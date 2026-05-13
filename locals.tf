##########################
# Local Values
##########################
# Computed values and constants used across the module
# Centralizing these improves maintainability and reduces duplication

locals {
  # Resource naming convention: {project_name}-{environment}-{resource_type}
  # Example: cts-sample-dev-app-vm
  resource_prefix = "${var.project_name}-${var.environment}"

  # Common tags applied to all instances
  common_tags = [
    "app-tier",
    "${var.environment}-app",
    "managed-by-terraform"
  ]

  # Network tags for firewall rules
  network_tags = concat(
    local.common_tags,
    var.enable_ssh_access ? ["allow-ssh-iap"] : [],
    var.network_tags
  )

  # Full network and subnet paths for Shared VPC
  # Format: projects/{host-project}/global/networks/{network-name}
  network_self_link = "projects/${var.network_project_id}/global/networks/${data.terraform_remote_state.network.outputs.vpc_name}"

  # Format: projects/{host-project}/regions/{region}/subnetworks/{subnet-name}
  subnet_self_link = "projects/${var.network_project_id}/regions/${var.region}/subnetworks/${data.terraform_remote_state.network.outputs.app_subnet_name}"

  # Common labels applied to all resources
  common_labels = merge(
    {
      managed_by  = "terraform"
      environment = var.environment
      tier        = "app"
      project     = var.project_name
      cost_center = var.environment # Useful for billing attribution
    },
    var.labels
  )

  # Default metadata for instances
  default_metadata = merge(
    {
      enable-oslogin         = "TRUE" # Use Google Cloud Identity for SSH authentication
      block-project-ssh-keys = "TRUE" # Enhanced security: don't use project-wide SSH keys
    },
    var.metadata
  )
}
