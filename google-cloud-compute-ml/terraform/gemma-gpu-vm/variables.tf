variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "instance_name" {
  description = "Name of the Compute Engine instance"
  type        = string
  default     = "gemma-gpu-vm"
}

variable "machine_type" {
  description = "Machine type for the VM"
  type        = string
  default     = "n1-standard-4"
}

variable "gpu_type" {
  description = "GPU type to attach"
  type        = string
  default     = "nvidia-tesla-t4"
}

variable "gpu_count" {
  description = "Number of GPUs to attach"
  type        = number
  default     = 1
}

variable "boot_disk_size" {
  description = "Boot disk size in GB"
  type        = number
  default     = 100
}

variable "use_spot" {
  description = "Use spot instances (preemptible) for cost savings"
  type        = bool
  default     = false
}

variable "create_gcs_bucket" {
  description = "Create a GCS bucket for data storage"
  type        = bool
  default     = true
}
