#!/usr/bin/env python3
"""
Submit a training job to Vertex AI with comprehensive configuration options.

Usage:
    python submit-training-job.py --config job_config.yaml
    python submit-training-job.py --machine-type a2-highgpu-1g --container-uri gcr.io/proj/image:tag
"""

# /// script
# dependencies = [
#   "google-cloud-aiplatform>=1.38.0",
#   "pyyaml>=6.0",
#   "click>=8.0",
# ]
# ///

import argparse
import json
import os
import sys
import yaml
from datetime import datetime
from pathlib import Path

try:
    from google.cloud import aiplatform
except ImportError:
    print("Error: google-cloud-aiplatform not installed")
    print("Run: pip install google-cloud-aiplatform")
    sys.exit(1)


def load_config(config_path: str) -> dict:
    """Load YAML or JSON config file."""
    with open(config_path, 'r') as f:
        if config_path.endswith('.json'):
            return json.load(f)
        return yaml.safe_load(f)


def build_worker_pool_spec(
    machine_type: str,
    container_uri: str,
    accelerator_type: str = None,
    accelerator_count: int = 0,
    replica_count: int = 1,
    command: list = None,
    args: list = None,
    env: dict = None,
    boot_disk_type: str = "pd-ssd",
    boot_disk_size_gb: int = 500,
) -> dict:
    """Build a worker pool specification."""
    spec = {
        "machine_spec": {"machine_type": machine_type},
        "replica_count": replica_count,
        "container_spec": {"image_uri": container_uri},
        "disk_spec": {
            "boot_disk_type": boot_disk_type,
            "boot_disk_size_gb": boot_disk_size_gb,
        },
    }
    
    if accelerator_type and accelerator_count > 0:
        spec["machine_spec"]["accelerator_type"] = accelerator_type
        spec["machine_spec"]["accelerator_count"] = accelerator_count
    
    if command:
        spec["container_spec"]["command"] = command
    if args:
        spec["container_spec"]["args"] = args
    if env:
        spec["container_spec"]["env"] = [
            {"name": k, "value": str(v)} for k, v in env.items()
        ]
    
    return spec


def submit_job(config: dict, project: str = None, location: str = None) -> aiplatform.CustomJob:
    """Submit a CustomJob to Vertex AI."""
    
    # Initialize Vertex AI
    project = project or os.environ.get("GOOGLE_CLOUD_PROJECT")
    location = location or config.get("location", "us-central1")
    
    if not project:
        raise ValueError("Project ID required. Set GOOGLE_CLOUD_PROJECT or pass --project.")
    
    aiplatform.init(project=project, location=location)
    
    # Build worker pool specs
    worker_pool_specs = []
    for pool in config.get("worker_pool_specs", [config]):
        spec = build_worker_pool_spec(
            machine_type=pool.get("machine_type", "n1-standard-4"),
            container_uri=pool.get("container_uri") or pool.get("image_uri"),
            accelerator_type=pool.get("accelerator_type"),
            accelerator_count=pool.get("accelerator_count", 0),
            replica_count=pool.get("replica_count", 1),
            command=pool.get("command"),
            args=pool.get("args"),
            env=pool.get("env", {}),
            boot_disk_type=pool.get("boot_disk_type", "pd-ssd"),
            boot_disk_size_gb=pool.get("boot_disk_size_gb", 500),
        )
        worker_pool_specs.append(spec)
    
    # Build job
    display_name = config.get("display_name", f"training-job-{datetime.now().strftime('%Y%m%d-%H%M%S')}")
    
    job_specs = {
        "display_name": display_name,
        "worker_pool_specs": worker_pool_specs,
    }
    
    # Add base output directory
    if "base_output_dir" in config:
        job_specs["base_output_dir"] = config["base_output_dir"]
    
    # Add scheduling config
    scheduling = config.get("scheduling", {})
    if scheduling.get("use_spot") or scheduling.get("strategy") == "SPOT":
        job_specs["scheduling"] = {
            "strategy": "SPOT",
            "max_wait_duration": scheduling.get("max_wait_duration", "3600s"),
        }
    elif "timeout" in scheduling:
        job_specs["scheduling"] = {
            "timeout": scheduling["timeout"],
        }
    
    # Add labels
    if "labels" in config:
        job_specs["labels"] = config["labels"]
    
    # Add service account
    if "service_account" in config:
        job_specs["service_account"] = config["service_account"]
    
    # Add tensorboard
    if "tensorboard" in config:
        job_specs["tensorboard"] = config["tensorboard"]
    
    # Create and run job
    job = aiplatform.CustomJob(**job_specs)
    
    sync = config.get("sync", False)
    job.run(sync=sync)
    
    return job


def main():
    parser = argparse.ArgumentParser(description="Submit training job to Vertex AI")
    parser.add_argument("--config", "-c", help="Path to config file (YAML or JSON)")
    parser.add_argument("--machine-type", "-m", default="n1-standard-4", help="Machine type")
    parser.add_argument("--accelerator-type", "-a", help="Accelerator type (e.g., NVIDIA_TESLA_A100)")
    parser.add_argument("--accelerator-count", type=int, default=0, help="Number of accelerators")
    parser.add_argument("--container-uri", "-i", help="Container image URI")
    parser.add_argument("--display-name", "-n", help="Job display name")
    parser.add_argument("--project", "-p", help="GCP project ID")
    parser.add_argument("--location", "-l", default="us-central1", help="GCP region")
    parser.add_argument("--use-spot", action="store_true", help="Use Spot VMs")
    parser.add_argument("--base-output-dir", "-o", help="Base output directory (GCS)")
    parser.add_argument("--timeout", type=int, help="Job timeout in seconds")
    parser.add_argument("--env", "-e", action="append", help="Environment variables (KEY=VALUE)")
    parser.add_argument("--save-job-id", default=".last_job_id", help="File to save job ID")
    parser.add_argument("--dry-run", action="store_true", help="Print config without submitting")
    
    args = parser.parse_args()
    
    # Build config from args or file
    if args.config:
        config = load_config(args.config)
    else:
        config = {
            "machine_type": args.machine_type,
            "container_uri": args.container_uri,
            "accelerator_type": args.accelerator_type,
            "accelerator_count": args.accelerator_count,
            "display_name": args.display_name or f"training-job-{datetime.now().strftime('%Y%m%d-%H%M%S')}",
            "base_output_dir": args.base_output_dir,
            "scheduling": {},
            "env": {},
        }
    
    # Apply CLI overrides
    if args.container_uri:
        config["container_uri"] = args.container_uri
    if args.display_name:
        config["display_name"] = args.display_name
    if args.use_spot:
        config.setdefault("scheduling", {})["use_spot"] = True
    if args.timeout:
        config.setdefault("scheduling", {})["timeout"] = f"{args.timeout}s"
    if args.base_output_dir:
        config["base_output_dir"] = args.base_output_dir
    if args.env:
        for env_var in args.env:
            key, value = env_var.split("=", 1)
            config.setdefault("env", {})[key] = value
    
    # Validate
    if not config.get("container_uri"):
        parser.error("--container-uri is required (or set in config file)")
    
    if args.dry_run:
        print("Configuration:")
        print(json.dumps(config, indent=2))
        return
    
    # Submit job
    try:
        print(f"Submitting job '{config['display_name']}' to {args.location}...")
        job = submit_job(config, args.project, args.location)
        
        job_id = job.resource_name.split("/")[-1]
        print(f"\n✅ Job submitted successfully!")
        print(f"   Job ID: {job_id}")
        print(f"   Resource: {job.resource_name}")
        print(f"   State: {job.state}")
        
        # Save job ID for monitoring
        if args.save_job_id:
            Path(args.save_job_id).write_text(job_id)
            print(f"   Job ID saved to: {args.save_job_id}")
        
        print(f"\nMonitor with:")
        print(f"   gcloud ai custom-jobs describe {job_id} --region={args.location}")
        print(f"   gcloud ai custom-jobs stream-logs {job_id} --region={args.location}")
        
    except Exception as e:
        print(f"\n❌ Error submitting job: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
