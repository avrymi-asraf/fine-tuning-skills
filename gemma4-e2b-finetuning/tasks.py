#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "invoke>=2.2.0",
#     "pyyaml>=6.0",
# ]
# ///
"""
Invoke tasks for Gemma 4 E2B fine-tuning on Vertex AI.

Usage:
    uv run tasks.py --list

    # One command for the full flow
    uv run tasks.py run --project-id my-project --bucket-name my-gemma-bucket

    # Optional helpers
    uv run tasks.py submit --project-id my-project --bucket-name my-gemma-bucket
    uv run tasks.py monitor-last --region us-central1
    uv run tasks.py cancel-last --region us-central1
"""

from __future__ import annotations

import os
from datetime import datetime
from pathlib import Path

import yaml
from invoke import Program, task

ROOT_DIR = Path(__file__).resolve().parent
REPO_ROOT = ROOT_DIR.parent
STATE_DIR = ROOT_DIR / "state"
STATE_DIR.mkdir(parents=True, exist_ok=True)

PROJECT_ID = os.getenv("PROJECT_ID", "")
REGION = os.getenv("REGION", "us-central1")
REPO_NAME = os.getenv("REPO_NAME", "ml-containers")
IMAGE_NAME = os.getenv("IMAGE_NAME", "gemma4-train")
IMAGE_TAG = os.getenv("IMAGE_TAG", "v1.0.0")
BUCKET_NAME = os.getenv("BUCKET_NAME", "")
DATASET_PATH = os.getenv("DATASET_PATH", "data/formatted_dataset")
DATASET_GCS_PREFIX = os.getenv("DATASET_GCS_PREFIX", "datasets/gemma4-e2b-v1")
VERTEX_CONFIG_TEMPLATE = os.getenv("VERTEX_CONFIG_TEMPLATE", "configs/vertex_job.yaml")
LAST_JOB_FILE = STATE_DIR / ".last_job_id"
RENDERED_VERTEX_CONFIG = STATE_DIR / "vertex_job.rendered.yaml"


def _require(value: str, name: str) -> None:
    if not value:
        raise ValueError(
            f"{name} is required. Pass --{name.lower().replace('_', '-')} or set env var {name}."
        )


def _image_uri(project_id: str, region: str, repo_name: str, image_name: str, image_tag: str) -> str:
    return f"{region}-docker.pkg.dev/{project_id}/{repo_name}/{image_name}:{image_tag}"


def _render_vertex_config(template_path: Path, image_uri: str, bucket_name: str) -> Path:
    with template_path.open("r", encoding="utf-8") as f:
        cfg = yaml.safe_load(f)

    pools = cfg.get("workerPoolSpecs", [])
    if not pools:
        raise ValueError("vertex_job.yaml must contain workerPoolSpecs")

    first_pool = pools[0]
    container_spec = first_pool.setdefault("containerSpec", {})
    container_spec["imageUri"] = image_uri

    env_entries = container_spec.setdefault("env", [])
    has_gcs_bucket = False
    for entry in env_entries:
        if entry.get("name") == "GCS_BUCKET":
            entry["value"] = f"gs://{bucket_name}"
            has_gcs_bucket = True
            break
    if not has_gcs_bucket:
        env_entries.append({"name": "GCS_BUCKET", "value": f"gs://{bucket_name}"})

    RENDERED_VERTEX_CONFIG.parent.mkdir(parents=True, exist_ok=True)
    with RENDERED_VERTEX_CONFIG.open("w", encoding="utf-8") as f:
        yaml.safe_dump(cfg, f, sort_keys=False)

    return RENDERED_VERTEX_CONFIG


@task
def doctor(c):
    """Check required local tools (gcloud, docker, uv)."""
    for cmd in ["gcloud --version", "docker --version", "uv --version"]:
        print(f"Running: {cmd}")
        c.run(cmd, pty=True)


@task
def check_quota(c, project_id=PROJECT_ID, region=REGION):
    """Check GPU quota before submitting training jobs."""
    _require(project_id, "PROJECT_ID")
    cmd = (
        f"{REPO_ROOT}/cloud-infrastructure-setup/scripts/gcp_diagnose.sh "
        f"quotas {project_id} {region}"
    )
    print(f"Running: {cmd}")
    c.run(cmd, pty=True)


@task
def build(c, image_name=IMAGE_NAME, image_tag=IMAGE_TAG):
    """Build the local training image."""
    cmd = f"DOCKER_BUILDKIT=1 docker build -t {image_name}:{image_tag} ."
    print(f"Running: {cmd}")
    with c.cd(str(ROOT_DIR)):
        c.run(cmd, pty=True)


@task
def push(
    c,
    project_id=PROJECT_ID,
    region=REGION,
    repo_name=REPO_NAME,
    image_name=IMAGE_NAME,
    image_tag=IMAGE_TAG,
):
    """Tag and push the image to Artifact Registry."""
    _require(project_id, "PROJECT_ID")
    uri = _image_uri(project_id, region, repo_name, image_name, image_tag)

    cmd_auth = f"gcloud auth configure-docker {region}-docker.pkg.dev --quiet"
    cmd_tag = f"docker tag {image_name}:{image_tag} {uri}"
    cmd_push = f"docker push {uri}"

    print(f"Running: {cmd_auth}")
    c.run(cmd_auth, pty=True)
    print(f"Running: {cmd_tag}")
    c.run(cmd_tag, pty=True)
    print(f"Running: {cmd_push}")
    c.run(cmd_push, pty=True)
    print(f"Pushed image: {uri}")


@task
def prepare_data(
    c,
    dataset_name="yahma/alpaca-cleaned",
    max_samples="",
    max_seq_length=2048,
    output_path=DATASET_PATH,
):
    """Prepare training dataset locally."""
    parts = [
        "uv run python data/prepare_dataset.py",
        f"--dataset_name {dataset_name}",
        f"--max_seq_length {max_seq_length}",
        f"--output_path {output_path}",
    ]
    if str(max_samples).strip():
        parts.append(f"--max_samples {max_samples}")

    cmd = " ".join(parts)
    print(f"Running: {cmd}")
    with c.cd(str(ROOT_DIR)):
        c.run(cmd, pty=True)


@task
def upload_data(
    c,
    bucket_name=BUCKET_NAME,
    dataset_path=DATASET_PATH,
    dataset_gcs_prefix=DATASET_GCS_PREFIX,
):
    """Upload prepared dataset to GCS."""
    _require(bucket_name, "BUCKET_NAME")
    target = f"gs://{bucket_name}/{dataset_gcs_prefix}/"
    cmd = f"gcloud storage cp -r {dataset_path}/* {target}"
    print(f"Running: {cmd}")
    with c.cd(str(ROOT_DIR)):
        c.run(cmd, pty=True)


@task
def render_config(
    c,
    project_id=PROJECT_ID,
    region=REGION,
    repo_name=REPO_NAME,
    image_name=IMAGE_NAME,
    image_tag=IMAGE_TAG,
    bucket_name=BUCKET_NAME,
    template_path=VERTEX_CONFIG_TEMPLATE,
):
    """Render the Vertex config with concrete image URI and bucket."""
    del c
    _require(project_id, "PROJECT_ID")
    _require(bucket_name, "BUCKET_NAME")

    image_uri = _image_uri(project_id, region, repo_name, image_name, image_tag)
    rendered = _render_vertex_config(ROOT_DIR / template_path, image_uri, bucket_name)
    print(f"Rendered config: {rendered}")
    print(f"Image URI: {image_uri}")


@task(pre=[render_config])
def submit(c, project_id=PROJECT_ID, region=REGION, display_name="gemma4-e2b-train"):
    """Submit the Vertex AI custom job and save last job ID."""
    _require(project_id, "PROJECT_ID")

    full_display_name = f"{display_name}-{datetime.utcnow().strftime('%Y%m%d-%H%M%S')}"
    cmd = (
        "set -euo pipefail\n"
        f"resource_name=$(gcloud ai custom-jobs create --project={project_id} "
        f"--region={region} --display-name={full_display_name} "
        f"--config={RENDERED_VERTEX_CONFIG} --format='value(name)')\n"
        "job_id=${resource_name##*/}\n"
        f"echo \"$job_id\" > {LAST_JOB_FILE}\n"
        "echo \"Submitted Vertex job: $job_id\"\n"
        "echo \"Resource: $resource_name\"\n"
    )
    print("Running: gcloud ai custom-jobs create ...")
    c.run(cmd, pty=True)


@task
def monitor_last(c, region=REGION):
    """Monitor the most recently submitted job from state/.last_job_id."""
    if not LAST_JOB_FILE.exists():
        raise FileNotFoundError(f"Missing {LAST_JOB_FILE}. Submit a job first.")

    job_id = LAST_JOB_FILE.read_text(encoding="utf-8").strip()
    cmd = f"{REPO_ROOT}/cloud-job-orchestration/scripts/monitor-job.sh {job_id} {region}"
    print(f"Running: {cmd}")
    c.run(cmd, pty=True)


@task
def stream_logs(c, region=REGION, job_id=""):
    """Stream logs for a given job ID (or fallback to state/.last_job_id)."""
    resolved_job_id = job_id.strip()
    if not resolved_job_id:
        if not LAST_JOB_FILE.exists():
            raise FileNotFoundError("No job_id provided and state/.last_job_id does not exist.")
        resolved_job_id = LAST_JOB_FILE.read_text(encoding="utf-8").strip()

    cmd = f"gcloud ai custom-jobs stream-logs {resolved_job_id} --region={region}"
    print(f"Running: {cmd}")
    c.run(cmd, pty=True)


@task
def cancel_last(c, region=REGION):
    """Cancel the most recently submitted job from state/.last_job_id."""
    if not LAST_JOB_FILE.exists():
        raise FileNotFoundError(f"Missing {LAST_JOB_FILE}. Submit a job first.")

    job_id = LAST_JOB_FILE.read_text(encoding="utf-8").strip()
    cmd = f"gcloud ai custom-jobs cancel {job_id} --region={region}"
    print(f"Running: {cmd}")
    c.run(cmd, pty=True)


@task(pre=[check_quota, build, push, prepare_data, upload_data, render_config])
def run(c, project_id=PROJECT_ID, bucket_name=BUCKET_NAME, region=REGION):
    """Run the full flow: quota check, build/push, data upload, and submit."""
    _require(project_id, "PROJECT_ID")
    _require(bucket_name, "BUCKET_NAME")

    submit(c, project_id=project_id, region=region)


if __name__ == "__main__":
    Program().run()
