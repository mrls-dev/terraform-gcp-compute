#!/bin/bash

# Setup Workload Identity Federation for GitHub Actions
# This script configures authentication for the compute infrastructure deployment

set -e

# Configuration
PROJECT_ID="project-70f3c2b9-8f91-41f7-b5c"
NETWORK_PROJECT_ID="mrls-dev-network"
GITHUB_REPO="mrls-dev/terraform-gcp-compute"  # Change to your actual GitHub org/repo
POOL_NAME="github-pool-app"
PROVIDER_NAME="github-provider-app"
SERVICE_ACCOUNT_NAME="terraform"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "=================================================="
echo "Workload Identity Setup for Compute Infrastructure"
echo "=================================================="
echo "Project: ${PROJECT_ID}"
echo "Network Project: ${NETWORK_PROJECT_ID}"
echo "GitHub Repo: ${GITHUB_REPO}"
echo "=================================================="

# Step 1: Create service account
echo ""
echo "Step 1: Creating service account..."
if gcloud iam service-accounts describe ${SERVICE_ACCOUNT_EMAIL} --project=${PROJECT_ID} &>/dev/null; then
    echo "Service account already exists: ${SERVICE_ACCOUNT_EMAIL}"
else
    gcloud iam service-accounts create ${SERVICE_ACCOUNT_NAME} \
        --display-name="Terraform Service Account for Compute" \
        --project=${PROJECT_ID}
    echo "Service account created: ${SERVICE_ACCOUNT_EMAIL}"
fi

# Step 2: Grant IAM roles on ${PROJECT_ID} (compute project)
echo ""
echo "Step 2: Granting IAM roles on ${PROJECT_ID}..."

# Compute instance admin
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/compute.instanceAdmin.v1" \
    --condition=None

# Service account user (to attach service accounts to VMs)
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/iam.serviceAccountUser" \
    --condition=None

echo "Granted roles on ${PROJECT_ID}"

# Step 3: Grant network user role on mrls-dev-network (for Shared VPC)
echo ""
echo "Step 3: Granting network access on ${NETWORK_PROJECT_ID}..."

gcloud projects add-iam-policy-binding ${NETWORK_PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/compute.networkUser" \
    --condition=None

echo "Granted network user role on ${NETWORK_PROJECT_ID}"

# Step 4: Create Workload Identity Pool
echo ""
echo "Step 4: Creating Workload Identity Pool..."
if gcloud iam workload-identity-pools describe ${POOL_NAME} \
    --location=global \
    --project=${PROJECT_ID} &>/dev/null; then
    echo "Workload Identity Pool already exists: ${POOL_NAME}"
else
    gcloud iam workload-identity-pools create ${POOL_NAME} \
        --location=global \
        --display-name="GitHub Actions Pool for Compute" \
        --project=${PROJECT_ID}
    echo "Workload Identity Pool created: ${POOL_NAME}"
fi

# Step 5: Create Workload Identity Provider
echo ""
echo "Step 5: Creating Workload Identity Provider..."
if gcloud iam workload-identity-pools providers describe ${PROVIDER_NAME} \
    --workload-identity-pool=${POOL_NAME} \
    --location=global \
    --project=${PROJECT_ID} &>/dev/null; then
    echo "Workload Identity Provider already exists: ${PROVIDER_NAME}"
else
    gcloud iam workload-identity-pools providers create-oidc ${PROVIDER_NAME} \
        --workload-identity-pool=${POOL_NAME} \
        --location=global \
        --issuer-uri="https://token.actions.githubusercontent.com" \
        --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
        --attribute-condition="assertion.repository_owner == '$(echo ${GITHUB_REPO} | cut -d'/' -f1)'" \
        --project=${PROJECT_ID}
    echo "Workload Identity Provider created: ${PROVIDER_NAME}"
fi

# Step 6: Bind service account to Workload Identity
echo ""
echo "Step 6: Binding service account to Workload Identity..."
gcloud iam service-accounts add-iam-policy-binding ${SERVICE_ACCOUNT_EMAIL} \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/projects/$(gcloud projects describe ${PROJECT_ID} --format='value(projectNumber)')/locations/global/workloadIdentityPools/${POOL_NAME}/attribute.repository/${GITHUB_REPO}" \
    --project=${PROJECT_ID}

echo "Service account bound to Workload Identity"

# Step 7: Get project number for workflow configuration
echo ""
echo "=================================================="
echo "Configuration Complete!"
echo "=================================================="
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format='value(projectNumber)')

echo ""
echo "Add these values to your GitHub Actions workflow:"
echo ""
echo "WORKLOAD_IDENTITY_PROVIDER: 'projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_NAME}/providers/${PROVIDER_NAME}'"
echo "SERVICE_ACCOUNT: '${SERVICE_ACCOUNT_EMAIL}'"
echo ""
echo "GitHub Repository: ${GITHUB_REPO}"
echo ""
echo "=================================================="
echo "Next Steps:"
echo "1. Update .github/workflows/terraform-dev.yml with the values above"
echo "2. Push changes to GitHub"
echo "3. The workflow will authenticate using Workload Identity"
echo "=================================================="
