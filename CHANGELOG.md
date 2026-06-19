# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of GCP Compute Infrastructure Terraform module
- Support for Google Compute Engine instances in Shared VPC configuration
- Remote state integration with network module
- GitHub Actions CI/CD workflow
- Comprehensive variable validation
- IAP-based SSH access configuration
- Free tier compatible defaults (e2-micro)
- Automated documentation generation
- TFLint and terraform-docs integration
- Pre-commit hooks for code quality
- Makefile for common operations
- EditorConfig for consistent formatting

### Features
- Multi-project Shared VPC architecture
- Workload Identity Federation for GitHub Actions
- Configurable startup scripts
- Custom metadata and labels support
- Flexible network tagging
- Optional external IP assignment
- Deletion protection support
- Comprehensive output values

### Documentation
- Detailed README with usage examples
- Contributing guidelines
- Security best practices guide
- Shared VPC setup instructions
- GitHub Actions setup guide
- Example variable files

## [1.0.0] - YYYY-MM-DD

### Added
- Initial stable release

## [1.0.1] - 2026-06-19
### Added
- CUDA Auto installation based on OS flavour

---

**Legend:**
- `Added` for new features
- `Changed` for changes in existing functionality
- `Deprecated` for soon-to-be removed features
- `Removed` for now removed features
- `Fixed` for any bug fixes
- `Security` for vulnerability fixes
