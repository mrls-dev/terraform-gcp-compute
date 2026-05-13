##########################
# Terraform Version Constraints
##########################
# Defines the minimum Terraform version and required providers
# This ensures consistent behavior across different environments

terraform {
  # Require Terraform 1.5.0 or higher
  # This version introduced native test framework and improved validation
  required_version = ">= 1.5.0"

  required_providers {
    # Google Cloud Platform provider
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
      # Version 5.x provides improved resource handling and API coverage
      # The ~> constraint allows patch updates (5.x.y) but not major updates
    }
  }
}
