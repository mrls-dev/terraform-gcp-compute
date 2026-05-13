##########################
# Backend Configuration
##########################
# Google Cloud Storage backend for Terraform state
#
# Features:
# - State locking (native GCS support)
# - Encryption at rest (Google-managed keys)
# - Versioning enabled on the bucket
# - Separate state files per environment
#
# Usage:
#   terraform init -backend-config=backend-dev.hcl
#   terraform init -backend-config=backend-prod.hcl
#
# The backend configuration is intentionally kept separate from the code
# to allow for environment-specific state storage without code changes.

terraform {
  backend "gcs" {
    # Configuration provided via backend-{env}.hcl files
    # Required parameters:
    #   - bucket: GCS bucket name for state storage
    #   - prefix: Path prefix within the bucket
    #
    # Example backend-dev.hcl:
    #   bucket = "your-org-terraform-state-dev"
    #   prefix = "infra/compute/dev"
  }
}
