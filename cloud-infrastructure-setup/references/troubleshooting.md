# Troubleshooting GCP ML Infrastructure Issues

Common issues and solutions when setting up and using GCP infrastructure for ML training.

## Authentication Issues

### Issue: `403 Forbidden` or `PERMISSION_DENIED`

**Symptoms:**
```
ERROR: (gcloud.projects.describe) User [user@example.com] does not have permission to access projects instance [PROJECT_ID] (or it may not exist)
```

**Solutions:**

1. **Verify authentication:**
   ```bash
   gcloud auth list
   # Should show ACTIVE account
   ```

2. **Re-authenticate:**
   ```bash
   gcloud auth login
   ```

3. **Check project access:**
   ```bash
   gcloud projects list
   # If project not listed, request access from project owner
   ```

4. **Verify IAM role:**
   ```bash
   gcloud projects get-iam-policy PROJECT_ID --filter="bindings.members:user:$(gcloud config get-value account)"
   ```

### Issue: Application Default Credentials Not Found

**Symptoms:**
```
DefaultCredentialsError: Could not automatically determine credentials
```

**Solutions:**

1. **Set up ADC:**
   ```bash
   gcloud auth application-default login
   ```

2. **Set environment variable:**
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json
   ```

3. **Verify ADC file exists:**
   ```bash
   ls -la ~/.config/gcloud/application_default_credentials.json
   ```

### Issue: Service Account Key Expired

**Symptoms:**
```
Error: invalid_grant: Token has been expired or revoked
```

**Solutions:**

1. **Create new key:**
   ```bash
   gcloud iam service-accounts keys create new-key.json \
     --iam-account=SA_NAME@PROJECT_ID.iam.gserviceaccount.com
   ```

2. **Update environment:**
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/new-key.json
   ```

3. **Delete old key:**
   ```bash
   gcloud iam service-accounts keys list \
     --iam-account=SA_NAME@PROJECT_ID.iam.gserviceaccount.com
   
   gcloud iam service-accounts keys delete KEY_ID \
     --iam-account=SA_NAME@PROJECT_ID.iam.gserviceaccount.com
   ```

---

## API Issues

### Issue: API Not Enabled

**Symptoms:**
```
API has not been used in project PROJECT_ID before or it is disabled
```

**Solutions:**

1. **Enable the API:**
   ```bash
   gcloud services enable aiplatform.googleapis.com
   ```

2. **Enable all required ML APIs:**
   ```bash
   gcloud services enable \
     aiplatform.googleapis.com compute.googleapis.com \
     storage.googleapis.com artifactregistry.googleapis.com \
     cloudbuild.googleapis.com logging.googleapis.com monitoring.googleapis.com
   ```

3. **Verify API is enabled:**
   ```bash
   gcloud services list --enabled | grep aiplatform
   ```

### Issue: Quota Exceeded

**Symptoms:**
```
Quota exceeded for quota group 'CUSTOM_JOB_CREATE' and limit 'CustomJob create requests per minute'
```

**Solutions:**

1. **Check current quota:**
   ```bash
   gcloud compute regions describe us-central1 --format="table(quotas.metric, quotas.limit, quotas.usage)"
   ```

2. **Request quota increase:**
   - Go to Cloud Console → IAM & Admin → Quotas
   - Select the metric → Edit Quotas
   - Submit request with justification

3. **Use different region:**
   ```bash
   gcloud config set compute/region us-east1
   ```

---

## Storage Issues

### Issue: GCS Bucket Permission Denied

**Symptoms:**
```
AccessDeniedException: 403 user@example.com does not have storage.objects.list access to the Google Cloud Storage bucket
```

**Solutions:**

1. **Grant storage role:**
   ```bash
   gsutil iam ch user:user@example.com:objectAdmin gs://BUCKET_NAME
   ```

2. **Use project-level binding:**
   ```bash
   gcloud projects add-iam-policy-binding PROJECT_ID \
     --member="user:user@example.com" \
     --role="roles/storage.objectAdmin"
   ```

3. **Verify bucket exists:**
   ```bash
   gsutil ls gs://BUCKET_NAME
   ```

### Issue: Bucket Not Found

**Symptoms:**
```
NotFoundException: 404 gs://BUCKET_NAME bucket does not exist
```

**Solutions:**

1. **Create bucket:**
   ```bash
   gsutil mb -l us-central1 gs://BUCKET_NAME
   ```

2. **Verify bucket name:**
   ```bash
   gsutil ls
   ```

3. **Check project:**
   ```bash
   gcloud config get-value project
   ```

---

## Vertex AI Issues

### Issue: Training Job Fails Immediately

**Symptoms:**
```
Job state: JOB_STATE_FAILED
Error: The replica workerpool0-0 exited with a non-zero status of 1
```

**Solutions:**

1. **Check logs:**
   ```bash
   gcloud ai custom-jobs stream-logs JOB_ID
   ```

2. **Verify Python package:**
   ```bash
   # Test locally first
   python -m trainer.task --epochs=1 --local
   
   # Check package structure
   tar -tzf trainer-0.1.tar.gz | head -20
   ```

3. **Check entry point:**
   ```bash
   # Verify python_module exists in package
   tar -tzf trainer-0.1.tar.gz | grep "trainer/task.py"
   ```

### Issue: Container Image Pull Failed

**Symptoms:**
```
ImagePullBackOff: Back-off pulling image
```

**Solutions:**

1. **Verify image exists:**
   ```bash
   gcloud artifacts docker images list us-central1-docker.pkg.dev/PROJECT/REPO
   ```

2. **Check image URI:**
   ```bash
   # Correct format for Artifact Registry
   us-central1-docker.pkg.dev/PROJECT_ID/REPO_NAME/IMAGE:TAG
   
   # Correct format for prebuilt containers
   us-docker.pkg.dev/vertex-ai/training/tf-gpu.2-12:latest
   ```

3. **Grant Artifact Registry access:**
   ```bash
   gcloud projects add-iam-policy-binding PROJECT_ID \
     --member="serviceAccount:SA@PROJECT.iam.gserviceaccount.com" \
     --role="roles/artifactregistry.reader"
   ```

### Issue: Compute Engine GPU Not Available

**Symptoms:**
```
RESOURCE_EXHAUSTED: Quota 'NVIDIA_TESLA_T4_GPUS' exceeded
```

This is a **Compute Engine** quota — applies to GPU VMs created directly.

**Solutions:**

1. **Check GPU quota:**
   ```bash
   gcloud compute regions describe us-central1 | grep -i gpu
   ```

2. **Try different GPU type or region:**
   ```bash
   gcloud compute accelerator-types list --filter="zone:us-central1"
   ```

3. **Request quota increase:**
   - Console → IAM & Admin → Quotas → filter for GPU type

### Issue: Vertex AI Training GPU Quota Exhausted

**Symptoms:**
```
RESOURCE_EXHAUSTED: Quota 'custom_model_training_nvidia_t4_gpus' exceeded
```

This is a **Vertex AI training** quota — separate from Compute Engine GPU quota. Each GPU type has its own training metric (e.g. `custom_model_training_nvidia_t4_gpus`, `custom_model_training_nvidia_a100_gpus`). These default to 0 in most projects.

**Solutions:**

1. **Check Vertex AI training quota:**
   ```bash
   ./scripts/gcp_diagnose.sh quotas PROJECT_ID us-central1
   ```

2. **Don't try different GPU types blindly** — each training GPU type has a separate quota metric. Check all of them before switching.

3. **Request increase for the specific training metric:**
   - Console → IAM & Admin → Quotas
   - Filter for `custom_model_training` → select the GPU metric → Edit Quotas
   - Allow 2–3 business days for approval

4. **While waiting for quota** — validate your container with a CPU-only smoke test:
   ```bash
   uv run scripts/submit-training-job.py --config my-job.yaml \
     --machine-type n1-standard-4 --accelerator-count 0
   ```

### Issue: Spot VM Preemption Loop

**Symptoms:**
```
Job failed with STOCKOUT error
Restart attempt 3/6
```

**Solutions:**

1. **Verify checkpointing is implemented:**
   ```python
   # Check that checkpoints are being saved
   import os
   os.system(f"gsutil ls gs://BUCKET/checkpoints/")
   ```

2. **Reduce resource requirements:**
   ```bash
   # Use fewer GPUs or smaller machine type
   --machine-type=n1-standard-4
   --accelerator-count=1
   ```

3. **Try different region/zone:**
   ```bash
   # Spot availability varies by region
   gcloud config set compute/region europe-west4
   ```

4. **Fall back to on-demand:**
   ```bash
   # Remove scheduling-strategy=SPOT
   gcloud ai custom-jobs create ...  # without SPOT
   ```

---

## Network Issues

### Issue: Cannot Connect to External Resources

**Symptoms:**
```
Connection timeout when downloading datasets
```

**Solutions:**

1. **Use GCS for data:**
   ```python
   # Download to GCS first, then read from there
   gsutil cp https://example.com/data.zip gs://BUCKET/data/
   ```

2. **Enable Private Google Access:**
   ```bash
   gcloud compute networks subnets update SUBNET \
     --enable-private-ip-google-access \
     --region=us-central1
   ```

3. **Configure firewall rules:**
   ```bash
   gcloud compute firewall-rules create allow-egress \
     --direction=EGRESS \
     --action=ALLOW \
     --destination-ranges=0.0.0.0/0 \
     --network=default
   ```

---

## Configuration Issues

### Issue: Wrong Project or Region

**Symptoms:**
```
ERROR: (gcloud.ai.custom-jobs.create) NOT_FOUND: Resource 'projects/WRONG_PROJECT/locations/WRONG_REGION' was not found
```

**Solutions:**

1. **Check current configuration:**
   ```bash
   gcloud config list
   ```

2. **Set correct project:**
   ```bash
   gcloud config set project CORRECT_PROJECT_ID
   ```

3. **Set correct region:**
   ```bash
   gcloud config set compute/region us-central1
   ```

4. **Use command-line flags:**
   ```bash
   gcloud ai custom-jobs list --project=PROJECT --region=us-central1
   ```

### Issue: Multiple gcloud Configurations Confusion

**Symptoms:**
Commands work in one terminal but not another; different projects in different windows.

**Solutions:**

1. **List configurations:**
   ```bash
   gcloud config configurations list
   ```

2. **Show active configuration:**
   ```bash
   gcloud config configurations describe $(gcloud config configurations list --filter="is_active=true" --format="value(name)")
   ```

3. **Use consistent configuration:**
   ```bash
   # Switch to correct config
   gcloud config configurations activate prod
   
   # Or set environment variable
   export CLOUDSDK_ACTIVE_CONFIG_NAME=prod
   ```

4. **Switch to correct config:**
   ```bash
   gcloud config configurations activate prod
   ```

---

## Cost and Billing Issues

### Issue: Unexpected High Charges

**Symptoms:**
Billing shows much higher costs than expected.

**Solutions:**

1. **Check active jobs:**
   ```bash
   gcloud ai custom-jobs list --region=us-central1 --filter="state!=JOB_STATE_SUCCEEDED AND state!=JOB_STATE_FAILED"
   ```

2. **Cancel runaway jobs:**
   ```bash
   gcloud ai custom-jobs cancel JOB_ID --region=us-central1
   ```

3. **Set up budget alerts:**
   ```bash
   gcloud billing budgets create \
     --billing-account=XXXXXX-XXXXXX-XXXXXX \
     --display-name="ML Budget" \
     --budget-amount=1000USD \
     --threshold-rule=percent=50 \
     --threshold-rule=percent=80 \
     --threshold-rule=percent=100
   ```

4. **Review cost breakdown:**
   ```bash
   # In Console: Billing → Cost Table
   # Or query BigQuery billing export
   ```

### Issue: Free Trial Expired

**Symptoms:**
```
Billing account not configured for project
```

**Solutions:**

1. **Link billing account:**
   ```bash
   gcloud billing accounts list
   gcloud billing projects link PROJECT_ID --billing-account=XXXXXX-XXXXXX-XXXXXX
   ```

2. **Upgrade billing account:**
   - Console → Billing → Manage billing accounts
   - Upgrade from free trial

---

## Debugging Commands

### General Debugging

```bash
# Verbose output
gcloud --verbosity=debug ai custom-jobs describe JOB_ID

# HTTP request logging
gcloud --log-http ai custom-jobs list

# Check current auth
gcloud auth print-access-token
gcloud auth print-identity-token

# List all resources
gcloud projects list
gcloud services list --enabled
gcloud iam service-accounts list
```

### Vertex AI Debugging

```bash
# Get job details
gcloud ai custom-jobs describe JOB_ID --region=us-central1

# Stream logs in real-time
gcloud ai custom-jobs stream-logs JOB_ID --region=us-central1

# List all jobs with status
gcloud ai custom-jobs list --region=us-central1 --format="table(displayName, name.split(/).slice(-1).join(), state, createTime)"

# Get specific worker logs
gcloud logging read "resource.labels.job_id=JOB_ID" --limit=50
```

### Reset and Cleanup

```bash
# Revoke and re-authenticate
gcloud auth revoke
gcloud auth login
gcloud auth application-default login

# Reset configuration
gcloud config configurations delete CONFIG_NAME
gcloud init

# Clean up stuck jobs
gcloud ai custom-jobs list --region=us-central1 --filter="state=JOB_STATE_RUNNING" --format="value(name)" | \
  xargs -I {} gcloud ai custom-jobs cancel {} --region=us-central1
```

---

## Getting Help

### Official Resources

- [GCP Documentation](https://cloud.google.com/docs)
- [Vertex AI Troubleshooting](https://cloud.google.com/vertex-ai/docs/troubleshooting)
- [GCP Support](https://cloud.google.com/support)

### Community Resources

- [Stack Overflow - Google Cloud](https://stackoverflow.com/questions/tagged/google-cloud-platform)
- [Google Cloud Community](https://www.googlecloudcommunity.com/)

### Debug Information to Collect

When seeking help, provide:

1. **Error message** (full text)
2. **Command used** (exact command with flags)
3. **Configuration:**
   ```bash
   gcloud config list
   gcloud version
   ```
4. **Permissions:**
   ```bash
   gcloud auth list
   gcloud projects get-iam-policy PROJECT_ID --filter="bindings.members:$(gcloud config get-value account)"
   ```
5. **Project info:**
   ```bash
   gcloud projects describe PROJECT_ID
   ```
