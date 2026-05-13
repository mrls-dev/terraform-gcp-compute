##########################
# Compute Instance Outputs
##########################
# These outputs provide information about the created compute instance
# and its network configuration for use in other modules or for reference

##########################
# Instance Identification
##########################

output "instance_name" {
  description = "Name of the compute instance. Use this with gcloud commands or for reference."
  value       = google_compute_instance.app_vm.name
}

output "instance_id" {
  description = "Unique identifier of the compute instance. Useful for API calls and resource tracking."
  value       = google_compute_instance.app_vm.instance_id
}

output "instance_self_link" {
  description = "Full URI of the compute instance resource. Use for cross-resource references."
  value       = google_compute_instance.app_vm.self_link
}

output "instance_zone" {
  description = "GCP zone where the instance is deployed."
  value       = google_compute_instance.app_vm.zone
}

##########################
# Network Configuration
##########################

output "internal_ip" {
  description = "Internal (private) IP address of the instance. Use for internal networking and service discovery."
  value       = google_compute_instance.app_vm.network_interface[0].network_ip
}

output "external_ip" {
  description = "External (public) IP address of the instance if assigned. Returns null if no external IP is configured."
  value       = length(google_compute_instance.app_vm.network_interface[0].access_config) > 0 ? google_compute_instance.app_vm.network_interface[0].access_config[0].nat_ip : null
}

output "network_name" {
  description = "Name of the VPC network from the network module remote state. Confirms Shared VPC integration."
  value       = data.terraform_remote_state.network.outputs.vpc_name
}

output "subnet_name" {
  description = "Name of the subnet where the instance is deployed. Retrieved from network module remote state."
  value       = data.terraform_remote_state.network.outputs.app_subnet_name
}

output "network_tags" {
  description = "Network tags applied to the instance. These determine which firewall rules apply."
  value       = google_compute_instance.app_vm.tags
}

##########################
# Access Information
##########################

output "ssh_command" {
  description = "Ready-to-use gcloud command for SSH access via Identity-Aware Proxy (IAP). No firewall rules or external IPs needed."
  value       = "gcloud compute ssh ${google_compute_instance.app_vm.name} --zone=${google_compute_instance.app_vm.zone} --project=${var.project_id} --tunnel-through-iap"
}

output "ssh_command_with_user" {
  description = "SSH command template with placeholder for username. Replace YOUR_USERNAME with your Google Cloud identity email."
  value       = "gcloud compute ssh YOUR_USERNAME@${google_compute_instance.app_vm.name} --zone=${google_compute_instance.app_vm.zone} --project=${var.project_id} --tunnel-through-iap"
}

##########################
# Resource Metadata
##########################

output "instance_labels" {
  description = "All labels applied to the instance. Useful for billing attribution and resource organization."
  value       = google_compute_instance.app_vm.labels
}

output "machine_type" {
  description = "Machine type of the instance. Useful for capacity planning and cost analysis."
  value       = google_compute_instance.app_vm.machine_type
}

output "service_account_email" {
  description = "Service account email attached to the instance. Shows which identity the instance uses for GCP API calls."
  value       = length(google_compute_instance.app_vm.service_account) > 0 ? google_compute_instance.app_vm.service_account[0].email : null
  sensitive   = false # Service account emails are not sensitive
}

##########################
# Operational Information
##########################

output "instance_status" {
  description = "Current status of the instance (e.g., RUNNING, TERMINATED). Check before performing operations."
  value       = google_compute_instance.app_vm.current_status
}

output "cpu_platform" {
  description = "The CPU platform used by this instance. Informational output showing actual hardware."
  value       = google_compute_instance.app_vm.cpu_platform
}

##########################
# GPU Information
##########################

output "gpu_enabled" {
  description = "Whether GPU is attached to this instance."
  value       = var.enable_gpu
}

output "gpu_type" {
  description = "Type of GPU attached (if any)."
  value       = var.enable_gpu ? var.gpu_type : null
}

output "gpu_count" {
  description = "Number of GPUs attached (if any)."
  value       = var.enable_gpu ? var.gpu_count : 0
}

output "cuda_test_command" {
  description = "Command to test CUDA installation (for GPU instances)."
  value       = var.enable_gpu ? "cd /opt/cuda-samples && ./hello_cuda" : "No GPU attached"
}

output "jupyter_tunnel_command" {
  description = "Command to create IAP tunnel for Jupyter Lab (for GPU instances)."
  value       = "gcloud compute start-iap-tunnel ${google_compute_instance.app_vm.name} 8888 --local-host-port=localhost:8888 --zone=${google_compute_instance.app_vm.zone} --project=${var.project_id}"
}
