terraform {
  required_version = ">= 1.0"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Call the module
module "gemma_gpu_vm" {
  source = "./modules/gemma-gpu-vm"

  project_id    = var.project_id
  region        = var.region
  zone          = var.zone
  instance_name = var.instance_name
  machine_type  = var.machine_type
  gpu_type      = var.gpu_type
  gpu_count     = var.gpu_count
  use_spot      = var.use_spot
  
  boot_disk_size    = var.boot_disk_size
  create_gcs_bucket = var.create_gcs_bucket
}
