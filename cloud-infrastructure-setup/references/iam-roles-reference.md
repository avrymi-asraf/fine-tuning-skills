# IAM Roles Reference for Vertex AI

Comprehensive reference for IAM roles and permissions required for ML training workloads.

## Predefined Roles

### Essential Roles for ML Training

#### roles/aiplatform.user
**Vertex AI User**

- Create and manage custom training jobs
- Create and manage datasets
- Create and manage endpoints
- Deploy models
- Access TensorBoard
- Run batch predictions

**Key permissions:**
- `aiplatform.customJobs.create`
- `aiplatform.customJobs.get`
- `aiplatform.customJobs.list`
- `aiplatform.customJobs.cancel`
- `aiplatform.datasets.create`
- `aiplatform.endpoints.deploy`
- `aiplatform.models.upload`
- `aiplatform.tensorboards.create`
- `aiplatform.tensorboards.write`

#### roles/storage.admin
**Storage Admin**

- Full control over GCS buckets and objects
- Required for reading training data and writing artifacts
- Includes all storage.object permissions

**Key permissions:**
- `storage.buckets.*`
- `storage.objects.*`
- `storage.multipartUploads.*`

#### roles/artifactregistry.reader
**Artifact Registry Reader**

- Pull container images from Artifact Registry
- Required for custom training containers

**Key permissions:**
- `artifactregistry.repositories.list`
- `artifactregistry.repositories.get`
- `artifactregistry.repositories.downloadArtifacts`
- `artifactregistry.files.list`
- `artifactregistry.files.get`

#### roles/artifactregistry.writer
**Artifact Registry Writer**

- Push and pull container images
- Required for building and storing custom training images

**Includes all reader permissions plus:**
- `artifactregistry.repositories.uploadArtifacts`
- `artifactregistry.tags.create`
- `artifactregistry.tags.update`

#### roles/cloudbuild.builds.editor
**Cloud Build Editor**

- Create and manage Cloud Build jobs
- Required for building custom container images

**Key permissions:**
- `cloudbuild.builds.create`
- `cloudbuild.builds.get`
- `cloudbuild.builds.list`
- `cloudbuild.builds.cancel`

#### roles/logging.logWriter
**Logs Writer**

- Write training logs to Cloud Logging
- Required for job monitoring and debugging

**Key permissions:**
- `logging.logEntries.create`
- `logging.logEntries.route`

#### roles/monitoring.metricWriter
**Monitoring Metric Writer**

- Write custom metrics during training
- Required for experiment tracking

**Key permissions:**
- `monitoring.metricDescriptors.create`
- `monitoring.metricDescriptors.get`
- `monitoring.timeSeries.create`

#### roles/iam.serviceAccountUser
**Service Account User**

- Run training jobs as a service account
- Required when specifying custom service accounts

**Key permissions:**
- `iam.serviceAccounts.actAs`

---

## Role Combinations by Use Case

### Minimal Training Job (Read-Only Data)

```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA@PROJECT.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA@PROJECT.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA@PROJECT.iam.gserviceaccount.com" \
  --role="roles/logging.logWriter"
```

### Full Training Pipeline (Custom Containers)

```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA@PROJECT.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA@PROJECT.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA@PROJECT.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA@PROJECT.iam.gserviceaccount.com" \
  --role="roles/cloudbuild.builds.editor"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA@PROJECT.iam.gserviceaccount.com" \
  --role="roles/logging.logWriter"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA@PROJECT.iam.gserviceaccount.com" \
  --role="roles/monitoring.metricWriter"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA@PROJECT.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"
```

### Data Scientist (Interactive Development)

```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:user@example.com" \
  --role="roles/aiplatform.user"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:user@example.com" \
  --role="roles/storage.objectAdmin"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:user@example.com" \
  --role="roles/bigquery.dataEditor"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:user@example.com" \
  --role="roles/notebooks.admin"
```

---

## Custom Role Example

Create a minimal custom role for training only:

```bash
cat > ml-training-role.yaml << EOF
title: "ML Training Runner"
description: "Minimal permissions for ML training jobs"
stage: "GA"
includedPermissions:
  # Vertex AI Custom Jobs
  - aiplatform.customJobs.create
  - aiplatform.customJobs.get
  - aiplatform.customJobs.list
  - aiplatform.customJobs.cancel
  
  # Datasets
  - aiplatform.datasets.get
  - aiplatform.datasets.list
  
  # Models
  - aiplatform.models.get
  - aiplatform.models.list
  - aiplatform.models.upload
  
  # Endpoints (for deployment)
  - aiplatform.endpoints.get
  - aiplatform.endpoints.list
  - aiplatform.endpoints.predict
  
  # TensorBoard
  - aiplatform.tensorboards.create
  - aiplatform.tensorboards.get
  - aiplatform.tensorboards.write
  - aiplatform.tensorboards.experiments.create
  - aiplatform.tensorboards.experiments.write
  - aiplatform.tensorboards.runs.create
  - aiplatform.tensorboards.timeSeries.create
  - aiplatform.tensorboards.timeSeries.write
  
  # Storage
  - storage.objects.create
  - storage.objects.delete
  - storage.objects.get
  - storage.objects.list
  - storage.buckets.get
  - storage.buckets.list
EOF

gcloud iam roles create MlTrainingRunner \
  --project=PROJECT_ID \
  --file=ml-training-role.yaml
```

---

## Permission Details by Resource

### Custom Training Jobs

| Operation | Required Permission |
|-----------|---------------------|
| Create | `aiplatform.customJobs.create` |
| Get | `aiplatform.customJobs.get` |
| List | `aiplatform.customJobs.list` |
| Cancel | `aiplatform.customJobs.cancel` |
| Delete | `aiplatform.customJobs.delete` |

### Datasets

| Operation | Required Permission |
|-----------|---------------------|
| Create | `aiplatform.datasets.create` |
| Get | `aiplatform.datasets.get` |
| List | `aiplatform.datasets.list` |
| Update | `aiplatform.datasets.update` |
| Delete | `aiplatform.datasets.delete` |
| Import | `aiplatform.datasets.import` |
| Export | `aiplatform.datasets.export` |

### Models

| Operation | Required Permission |
|-----------|---------------------|
| Upload | `aiplatform.models.upload` |
| Get | `aiplatform.models.get` |
| List | `aiplatform.models.list` |
| Delete | `aiplatform.models.delete` |
| Export | `aiplatform.models.export` |

### Endpoints

| Operation | Required Permission |
|-----------|---------------------|
| Create | `aiplatform.endpoints.create` |
| Get | `aiplatform.endpoints.get` |
| List | `aiplatform.endpoints.list` |
| Delete | `aiplatform.endpoints.delete` |
| Deploy | `aiplatform.endpoints.deploy` |
| Predict | `aiplatform.endpoints.predict` |
| Undeploy | `aiplatform.endpoints.undeploy` |

---

## Troubleshooting Permission Errors

### "Permission denied" on job creation

**Symptoms:**
```
PERMISSION_DENIED: Permission 'aiplatform.customJobs.create' denied
```

**Solution:**
```bash
# Grant Vertex AI User role
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:USER@example.com" \
  --role="roles/aiplatform.user"
```

### "Access Denied" on GCS bucket

**Symptoms:**
```
403 Access Denied on gs://BUCKET_NAME
```

**Solution:**
```bash
# Grant Storage Object Admin
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA@PROJECT.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"
```

### Cannot pull container image

**Symptoms:**
```
UNAUTHORIZED: authentication required
```

**Solution:**
```bash
# Grant Artifact Registry Reader
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA@PROJECT.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.reader"
```

### "Unable to act as service account"

**Symptoms:**
```
Failed to act as service account
```

**Solution:**
```bash
# Grant Service Account User role
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:USER@example.com" \
  --role="roles/iam.serviceAccountUser"
```

---

## Best Practices

1. **Principle of Least Privilege:** Grant only necessary permissions
2. **Service Accounts for Automation:** Use dedicated service accounts for CI/CD
3. **User Accounts for Development:** Use personal accounts for interactive work
4. **Regular Audits:** Review IAM policies quarterly
5. **Custom Roles:** Create custom roles for specific workflows
6. **Conditional Access:** Use IAM conditions for time-bound access

### Example: Conditional IAM Binding

```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:temp-user@example.com" \
  --role="roles/aiplatform.user" \
  --condition="expression=request.time < timestamp('2024-12-31T00:00:00Z'),title=TempAccess,description=Temporary access until end of 2024"
```
