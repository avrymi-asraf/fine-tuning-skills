output "instance_name" {
  description = "Name of the created Compute Engine instance"
  value       = module.gemma_gpu_vm.instance_name
}

output "zone" {
  description = "Zone where the instance is deployed"
  value       = module.gemma_gpu_vm.zone
}

output "machine_type" {
  description = "Machine type of the instance"
  value       = module.gemma_gpu_vm.machine_type
}

output "gpu_type" {
  description = "GPU type attached to the instance"
  value       = module.gemma_gpu_vm.gpu_type
}

output "external_ip" {
  description = "External IP address of the instance"
  value       = module.gemma_gpu_vm.external_ip
}

output "ssh_command" {
  description = "Command to SSH into the instance"
  value       = module.gemma_gpu_vm.ssh_command
}

output "gcs_bucket_name" {
  description = "Name of the GCS bucket for data storage"
  value       = module.gemma_gpu_vm.gcs_bucket_name
}

output "gcs_bucket_url" {
  description = "URL of the GCS bucket"
  value       = module.gemma_gpu_vm.gcs_bucket_url
}

output "connection_instructions" {
  description = "Instructions for connecting to the instance"
  value       = module.gemma_gpu_vm.connection_instructions
}
