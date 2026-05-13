# Shared VPC Setup Guide

This guide explains how to configure Shared VPC between `mrls-dev-network` (host) and `project-70f3c2b9-8f91-41f7-b5c` (service project).

## Architecture

```
mrls-dev-network (Host Project)
├── VPC: cts-sample-dev
├── Subnets: web, app, db
├── Cloud NAT
└── Firewall Rules

project-70f3c2b9-8f91-41f7-b5c (Service Project)
└── Compute Instances (uses network from mrls-dev-network)
```

## Prerequisites

You need the following permissions on the **organization** or **folder** level:
- `roles/compute.xpnAdmin` - To enable Shared VPC
- `roles/resourcemanager.projectIamAdmin` - To grant permissions

## Step 1: Enable Shared VPC on Host Project

```bash
# Enable mrls-dev-network as Shared VPC host
gcloud compute shared-vpc enable mrls-dev-network
```

## Step 2: Attach Service Project

```bash
# Attach service project
gcloud compute shared-vpc associated-projects add project-70f3c2b9-8f91-41f7-b5c \
  --host-project=mrls-dev-network
```

## Step 3: Grant Permissions

The service account or user deploying VMs in `project-70f3c2b9-8f91-41f7-b5c` needs permission to use subnets from `mrls-dev-network`:

```bash
# Grant network user role to the Terraform service account
gcloud projects add-iam-policy-binding mrls-dev-network \
  --member="serviceAccount:terraform@project-70f3c2b9-8f91-41f7-b5c.iam.gserviceaccount.com" \
  --role="roles/compute.networkUser"

# If using user account for local testing
gcloud projects add-iam-policy-binding mrls-dev-network \
  --member="user:$(gcloud config get-value account)" \
  --role="roles/compute.networkUser"
```

## Step 4: Grant Compute Admin on App Project

```bash
# Create terraform service account (if not exists)
gcloud iam service-accounts create terraform \
  --display-name="Terraform Service Account" \
  --project=project-70f3c2b9-8f91-41f7-b5c

# Grant compute instance admin
gcloud projects add-iam-policy-binding project-70f3c2b9-8f91-41f7-b5c \
  --member="serviceAccount:terraform@project-70f3c2b9-8f91-41f7-b5c.iam.gserviceaccount.com" \
  --role="roles/compute.instanceAdmin.v1"

# Grant service account user (to attach service accounts to VMs)
gcloud projects add-iam-policy-binding project-70f3c2b9-8f91-41f7-b5c \
  --member="serviceAccount:terraform@project-70f3c2b9-8f91-41f7-b5c.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

# For local testing with your user account
gcloud projects add-iam-policy-binding project-70f3c2b9-8f91-41f7-b5c \
  --member="user:$(gcloud config get-value account)" \
  --role="roles/compute.instanceAdmin.v1"

gcloud projects add-iam-policy-binding project-70f3c2b9-8f91-41f7-b5c \
  --member="user:$(gcloud config get-value account)" \
  --role="roles/iam.serviceAccountUser"
```

## Step 5: Enable Required APIs

```bash
# Enable Compute Engine API
gcloud services enable compute.googleapis.com --project=project-70f3c2b9-8f91-41f7-b5c

# Verify Compute Engine API is enabled in mrls-dev-network (should already be)
gcloud services list --enabled --project=mrls-dev-network | grep compute
```

## Verify Shared VPC Configuration

```bash
# List Shared VPC host projects
gcloud compute shared-vpc get-host-project project-70f3c2b9-8f91-41f7-b5c

# Expected output: mrls-dev-network

# List service projects attached to host
gcloud compute shared-vpc list-associated-resources mrls-dev-network

# Expected output should include project-70f3c2b9-8f91-41f7-b5c
```

## Test Network Access

After deploying a VM in `project-70f3c2b9-8f91-41f7-b5c`, verify it can use the network:

```bash
# SSH into the VM
gcloud compute ssh cts-sample-dev-app-vm \
  --zone=us-central1-a \
  --project=project-70f3c2b9-8f91-41f7-b5c \
  --tunnel-through-iap

# Inside the VM, test connectivity
ping -c 3 8.8.8.8          # Test Cloud NAT
curl https://www.google.com # Test internet access
```

## Troubleshooting

### Error: "Subnetwork should be specified for custom subnetmode network"

**Cause:** Trying to reference subnet without full project path.

**Solution:** Use full subnet path:
```hcl
subnetwork = "projects/mrls-dev-network/regions/us-central1/subnetworks/subnet-name"
```

### Error: "Required 'compute.subnetworks.use' permission"

**Cause:** Service account/user doesn't have network user role.

**Solution:** Grant `roles/compute.networkUser` on `mrls-dev-network`:
```bash
gcloud projects add-iam-policy-binding mrls-dev-network \
  --member="serviceAccount:terraform@project-70f3c2b9-8f91-41f7-b5c.iam.gserviceaccount.com" \
  --role="roles/compute.networkUser"
```

### Error: "The resource 'projects/mrls-dev-app' is not associated with the host project"

**Cause:** Service project not attached to Shared VPC host.

**Solution:** Run step 2 again to attach the service project.

## IAM Summary

**On mrls-dev-network (Host Project):**
- `roles/compute.networkUser` - For terraform service account and users

**On project-70f3c2b9-8f91-41f7-b5c (Service Project):**
- `roles/compute.instanceAdmin.v1` - To manage VMs
- `roles/iam.serviceAccountUser` - To attach service accounts to VMs

## Cleanup

To remove Shared VPC configuration:

```bash
# Detach service project
gcloud compute shared-vpc associated-projects remove project-70f3c2b9-8f91-41f7-b5c \
  --host-project=mrls-dev-network

# Disable Shared VPC on host
gcloud compute shared-vpc disable mrls-dev-network
```

## Additional Resources

- [Shared VPC Overview](https://cloud.google.com/vpc/docs/shared-vpc)
- [Provisioning Shared VPC](https://cloud.google.com/vpc/docs/provisioning-shared-vpc)
- [IAM Permissions for Shared VPC](https://cloud.google.com/vpc/docs/shared-vpc#iam_in_shared_vpc)
