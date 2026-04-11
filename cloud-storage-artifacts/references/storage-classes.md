# Cloud Storage Classes Comparison

## Quick Reference Table

| Provider | Frequent Access | Infrequent Access | Archive | Minimum Duration | Retrieval Fee |
|----------|-----------------|-------------------|---------|------------------|---------------|
| **GCS** | STANDARD | NEARLINE | COLDLINE, ARCHIVE | None / 30d / 90d / 365d | No / Yes |
| **S3** | S3 Standard | S3 Standard-IA | S3 Glacier, Deep Archive | None / 30d / 90d / 180d | No / Yes |
| **Azure** | Hot | Cool | Archive | None / 30d / 180d | No / Yes |

---

## Google Cloud Storage

### STANDARD
- **Best For**: Frequently accessed data, active ML training
- **Availability**: 99.99% (regional) / 99.99% (multi-regional)
- **Min Duration**: None
- **Retrieval Fee**: None
- **Latency**: Milliseconds
- **Use Case**: Training data, recent checkpoints, serving models

### NEARLINE
- **Best For**: Data accessed < once per month
- **Availability**: 99.9% (regional) / 99.95% (multi-regional)
- **Min Duration**: 30 days
- **Retrieval Fee**: Yes ($0.01/GB)
- **Latency**: Milliseconds
- **Use Case**: Previous experiments, model registry history

### COLDLINE
- **Best For**: Data accessed < once per quarter
- **Availability**: 99.9% (regional) / 99.95% (multi-regional)
- **Min Duration**: 90 days
- **Retrieval Fee**: Yes ($0.02/GB)
- **Latency**: Milliseconds
- **Use Case**: Archived experiments, old logs

### ARCHIVE
- **Best For**: Long-term backup, compliance
- **Availability**: 99.9% (regional) / 99.95% (multi-regional)
- **Min Duration**: 365 days
- **Retrieval Fee**: Yes ($0.05/GB)
- **Latency**: Milliseconds (sub-second)
- **Use Case**: Final model backups, regulatory compliance

### AUTOMATIC (GCS Only)
- **Best For**: Workloads with unknown/predictable access patterns
- **Availability**: Varies
- **Min Duration**: None
- **Retrieval Fee**: Varies
- **Latency**: Milliseconds
- **Use Case**: General purpose ML workloads

---

## Amazon S3

### S3 Standard
- **Best For**: Frequently accessed data
- **Availability**: 99.99%
- **Min Duration**: None
- **Retrieval Fee**: None
- **Use Case**: Active training data

### S3 Standard-IA
- **Best For**: Infrequently accessed data
- **Availability**: 99.9%
- **Min Duration**: 30 days
- **Retrieval Fee**: Yes ($0.01/GB)
- **Use Case**: Previous experiments

### S3 One Zone-IA
- **Best For**: Infrequently accessed, reproducible data
- **Availability**: 99.5% (single AZ)
- **Min Duration**: 30 days
- **Retrieval Fee**: Yes ($0.01/GB)
- **Use Case**: Temporary checkpoints (recomputable)

### S3 Glacier Instant Retrieval
- **Best For**: Archive with instant access
- **Availability**: 99.9%
- **Min Duration**: 90 days
- **Retrieval Fee**: Yes ($0.02/GB)
- **Use Case**: Model backups that might need quick access

### S3 Glacier Flexible Retrieval
- **Best For**: Archive with flexible retrieval
- **Availability**: 99.99%
- **Min Duration**: 90 days
- **Retrieval Fee**: Yes ($0.02/GB)
- **Retrieval Time**: Minutes to hours
- **Use Case**: Old model versions

### S3 Glacier Deep Archive
- **Best For**: Long-term archive
- **Availability**: 99.9%
- **Min Duration**: 180 days
- **Retrieval Fee**: Yes ($0.02/GB)
- **Retrieval Time**: 12+ hours
- **Use Case**: Compliance archives

---

## Azure Blob Storage

### Hot Tier
- **Best For**: Frequently accessed data
- **Availability**: 99.9% (LRS) / 99.99% (GRS)
- **Min Duration**: None
- **Retrieval Fee**: None
- **Use Case**: Active training data

### Cool Tier
- **Best For**: Infrequently accessed data
- **Availability**: 99% (LRS) / 99.9% (GRS)
- **Min Duration**: 30 days
- **Retrieval Fee**: Yes
- **Use Case**: Previous experiments

### Archive Tier
- **Best For**: Rarely accessed data
- **Availability**: 99% (LRS) / 99.9% (GRS)
- **Min Duration**: 180 days
- **Retrieval Fee**: Yes
- **Retrieval Time**: Hours
- **Use Case**: Long-term backups

---

## ML Workload Recommendations

### Training Phase
| Data Type | Recommended Class | Rationale |
|-----------|-------------------|-----------|
| Training dataset | STANDARD / Hot | Frequent reads |
| Validation dataset | STANDARD / Hot | Frequent reads |
| Recent checkpoints (< 7d) | STANDARD / Hot | Frequent resume |
| Intermediate checkpoints (7-30d) | NEARLINE / IA | Occasional rollback |
| Old checkpoints (> 30d) | COLDLINE / Glacier | Rarely accessed |

### Model Registry
| Model Type | Recommended Class | Rationale |
|------------|-------------------|-----------|
| Production models | STANDARD / Hot | Immediate serving |
| Staging models | NEARLINE / IA | Occasional testing |
| Archived versions | COLDLINE / Glacier | Compliance |

### Logging & Metrics
| Data Type | Recommended Class | Rationale |
|-----------|-------------------|-----------|
| Current logs | STANDARD / Hot | Active monitoring |
| Recent logs (7-30d) | STANDARD / Hot | Debugging |
| Old logs (30-90d) | NEARLINE / IA | Analysis |
| Historical logs (> 90d) | COLDLINE / Glacier / Delete | Archive or purge |

---

## Cost Comparison (per GB/month, approximate)

| Provider | Standard | Infrequent | Archive |
|----------|----------|------------|---------|
| **GCS** | $0.020 | $0.010 | $0.0012 |
| **S3** | $0.023 | $0.0125 | $0.00099 |
| **Azure** | $0.0184 | $0.0100 | $0.00099 |

*Note: Prices vary by region. Check provider pricing pages for exact costs.*

---

## Early Deletion Fees

| Provider | Class | Minimum Duration | Penalty |
|----------|-------|------------------|---------|
| GCS | NEARLINE | 30 days | Prorated remaining days |
| GCS | COLDLINE | 90 days | Prorated remaining days |
| GCS | ARCHIVE | 365 days | Prorated remaining days |
| S3 | Standard-IA | 30 days | Prorated remaining days |
| S3 | Glacier | 90 days | Prorated remaining days |
| Azure | Cool | 30 days | Prorated remaining days |
| Azure | Archive | 180 days | Prorated remaining days |

---

## Retrieval Fees (per GB)

| Provider | Class | Retrieval Fee |
|----------|-------|---------------|
| GCS | NEARLINE | ~$0.01 |
| GCS | COLDLINE | ~$0.02 |
| GCS | ARCHIVE | ~$0.05 |
| S3 | Standard-IA | $0.01 |
| S3 | Glacier IR | $0.02 |
| S3 | Glacier FR | $0.02 |
| Azure | Cool | ~$0.01 |
| Azure | Archive | ~$0.02 |
