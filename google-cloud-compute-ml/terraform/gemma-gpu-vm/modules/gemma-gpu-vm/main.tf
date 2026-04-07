# Gemma GPU VM Terraform Module
#
# Deploys a GPU-enabled Compute Engine VM for ML workloads

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Get project info
data "google_project" "project" {
  project_id = var.project_id
}

# Create the GPU-enabled VM
resource "google_compute_instance" "gemma_gpu" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone
  project      = var.project_id

  boot_disk {
    initialize_params {
      image = "projects/deeplearning-platform-release/global/images/family/${var.image_family}"
      size  = var.boot_disk_size
      type  = "pd-ssd"
    }
  }

  guest_accelerator {
    type  = var.gpu_type
    count = var.gpu_count
  }

  scheduling {
    on_host_maintenance = "TERMINATE"
    automatic_restart   = false
    # Enable spot instances for cost savings
    provisioning_model = var.use_spot ? "SPOT" : "STANDARD"
    preemptible        = var.use_spot
  }

  network_interface {
    network = "default"
    access_config {
      # Ephemeral external IP (not needed with IAP, but helpful for debugging)
    }
  }

  metadata = {
    install-nvidia-driver = "true"
    # Enable OS Login for secure SSH access
    enable-oslogin = "true"
  }

  labels = {
    purpose = "ml-training"
    model   = "gemma"
  }

  # Startup script to install additional packages
  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -e
    
    # Log startup script output
    exec > /var/log/startup-script.log 2>&1
    
    echo "Starting setup at $(date)"
    
    # Wait for NVIDIA driver installation
    for i in {1..30}; do
      if command -v nvidia-smi &> /dev/null; then
        echo "NVIDIA driver found"
        break
      fi
      echo "Waiting for NVIDIA driver... ($i/30)"
      sleep 10
    done
    
    # Update system packages
    apt-get update
    apt-get install -y tmux htop git-lfs
    
    echo "Setup complete at $(date)"
  EOF

  service_account {
    email  = var.service_account_email != "" ? var.service_account_email : google_service_account.gemma_sa[0].email
    scopes = ["cloud-platform"]
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Create a service account for the VM (if not provided)
resource "google_service_account" "gemma_sa" {
  count = var.service_account_email == "" ? 1 : 0

  account_id   = "${var.instance_name}-sa"
  display_name = "Service Account for ${var.instance_name}"
  project      = var.project_id
}

# Grant necessary permissions to the service account
resource "google_project_iam_member" "gemma_sa_permissions" {
  for_each = toset([
    "roles/storage.objectViewer",
    "roles/storage.objectCreator",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${var.service_account_email != "" ? var.service_account_email : google_service_account.gemma_sa[0].email}"
}

# Create a GCS bucket for data storage (optional)
resource "google_storage_bucket" "gemma_data" {
  count = var.create_gcs_bucket ? 1 : 0

  name          = "${var.project_id}-${var.instance_name}-data"
  location      = var.region
  project       = var.project_id
  force_destroy = true

  uniform_bucket_level_access = true

  labels = {
    purpose = "ml-data"
  }
}

# Grant VM service account access to the bucket
resource "google_storage_bucket_iam_member" "gemma_data_access" {
  count = var.create_gcs_bucket ? 1 : 0

  bucket = google_storage_bucket.gemma_data[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.service_account_email != "" ? var.service_account_email : google_service_account.gemma_sa[0].email}"
}
