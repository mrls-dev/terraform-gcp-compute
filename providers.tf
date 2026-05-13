##########################
# Provider Configuration
##########################
# Google Cloud Platform provider configuration
# Uses Workload Identity for authentication in CI/CD
# For local development, use: gcloud auth application-default login

provider "google" {
  project = var.project_id
  region  = var.region

  # Enable user_project_override for Shared VPC billing
  # This ensures API calls are billed to the service project, not the host project
  user_project_override = true

  # Default labels applied to all resources created by this provider
  default_labels = {
    managed_by  = "terraform"
    environment = var.environment
    repo        = "terraform-gcp-compute"
  }
}
