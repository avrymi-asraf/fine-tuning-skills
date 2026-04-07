output "instance_name" {
  description = "Name of the created Compute Engine instance"
  value       = google_compute_instance.gemma_gpu.name
}

output "instance_self_link" {
  description = "Self link of the Compute Engine instance"
  value       = google_compute_instance.gemma_gpu.self_link
}

output "instance_id" {
  description = "ID of the Compute Engine instance"
  value       = google_compute_instance.gemma_gpu.id
}

output "zone" {
  description = "Zone where the instance is deployed"
  value       = google_compute_instance.gemma_gpu.zone
}

output "machine_type" {
  description = "Machine type of the instance"
  value       = google_compute_instance.gemma_gpu.machine_type
}

output "gpu_type" {
  description = "GPU type attached to the instance"
  value       = var.gpu_type
}

output "external_ip" {
  description = "External IP address of the instance"
  value       = google_compute_instance.gemma_gpu.network_interface[0].access_config[0].nat_ip
}

output "ssh_command" {
  description = "Command to SSH into the instance"
  value       = "gcloud compute ssh ${google_compute_instance.gemma_gpu.name} --zone=${var.zone} --project=${var.project_id} --tunnel-through-iap"
}

output "gcs_bucket_name" {
  description = "Name of the GCS bucket for data storage"
  value       = var.create_gcs_bucket ? google_storage_bucket.gemma_data[0].name : null
}

output "gcs_bucket_url" {
  description = "URL of the GCS bucket"
  value       = var.create_gcs_bucket ? "gs://${google_storage_bucket.gemma_data[0].name}" : null
}

output "connection_instructions" {
  description = "Instructions for connecting to the instance"
  value       = <<-EOF

  ===== Connection Instructions =====
  
  1. SSH into the instance:
     ${"gcloud compute ssh ${google_compute_instance.gemma_gpu.name} --zone=${var.zone} --project=${var.project_id} --tunnel-through-iap"}
  
  2. Check GPU status:
     nvidia-smi
  
  3. Setup environment:
     ./scripts/gcp_setup.sh install-unsloth
  
  4. Upload data/model:
     ./scripts/gcp_transfer.sh upload ./local-data ${google_compute_instance.gemma_gpu.name}:/home/\$USER/data/
  
  5. Stop instance when done (to save money):
     ./scripts/gcp_compute.sh stop ${google_compute_instance.gemma_gpu.name}
  
  ${var.create_gcs_bucket ? "\n  GCS Bucket for data: gs://${google_storage_bucket.gemma_data[0].name}\n  " : ""}
  ===================================
  
  EOF
}
