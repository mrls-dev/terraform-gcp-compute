# Makefile for Terraform GCP Compute Infrastructure
# Provides convenient shortcuts for common operations

.PHONY: help init plan apply destroy validate fmt lint clean docs test

# Default environment (can be overridden: make plan ENV=prod)
ENV ?= dev

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo '${BLUE}Available targets:${NC}'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  ${GREEN}%-15s${NC} %s\n", $$1, $$2}'

init: ## Initialize Terraform with backend configuration
	@echo "${BLUE}Initializing Terraform for ${ENV} environment...${NC}"
	terraform init -backend-config=backend-$(ENV).hcl -upgrade

validate: ## Validate Terraform configuration
	@echo "${BLUE}Validating Terraform configuration...${NC}"
	terraform validate

fmt: ## Format Terraform files
	@echo "${BLUE}Formatting Terraform files...${NC}"
	terraform fmt -recursive

fmt-check: ## Check if Terraform files are formatted
	@echo "${BLUE}Checking Terraform formatting...${NC}"
	terraform fmt -check -recursive

lint: ## Run TFLint
	@echo "${BLUE}Running TFLint...${NC}"
	tflint --init
	tflint

plan: init validate ## Create Terraform execution plan
	@echo "${BLUE}Creating execution plan for ${ENV} environment...${NC}"
	terraform plan -var-file=$(ENV).tfvars -out=tfplan-$(ENV)

apply: ## Apply Terraform changes
	@echo "${BLUE}Applying Terraform changes for ${ENV} environment...${NC}"
	@if [ -f tfplan-$(ENV) ]; then \
		terraform apply tfplan-$(ENV); \
	else \
		terraform apply -var-file=$(ENV).tfvars; \
	fi

destroy: ## Destroy Terraform-managed infrastructure
	@echo "${RED}WARNING: This will destroy all resources in ${ENV} environment!${NC}"
	@echo "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
	@sleep 5
	terraform destroy -var-file=$(ENV).tfvars

output: ## Show Terraform outputs
	@echo "${BLUE}Terraform outputs for ${ENV} environment:${NC}"
	terraform output

ssh: ## SSH into the instance via IAP
	@echo "${BLUE}Connecting to instance via IAP...${NC}"
	@INSTANCE=$$(terraform output -raw instance_name 2>/dev/null); \
	ZONE=$$(terraform output -raw instance_zone 2>/dev/null); \
	PROJECT=$$(terraform output -json | jq -r '.instance_self_link.value' | cut -d'/' -f7); \
	gcloud compute ssh $$INSTANCE --zone=$$ZONE --project=$$PROJECT --tunnel-through-iap

clean: ## Clean up temporary files
	@echo "${BLUE}Cleaning up temporary files...${NC}"
	rm -f tfplan-*
	rm -f .terraform.lock.hcl
	rm -rf .terraform/

docs: ## Generate documentation with terraform-docs
	@echo "${BLUE}Generating Terraform documentation...${NC}"
	terraform-docs markdown table . --output-file TERRAFORM.md

test: fmt-check validate lint ## Run all tests (format check, validate, lint)
	@echo "${GREEN}All tests passed!${NC}"

all: fmt validate lint plan ## Format, validate, lint, and plan

.DEFAULT_GOAL := help
