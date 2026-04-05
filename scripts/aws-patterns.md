# AWS Patterns Reference

Concrete patterns drawn from real scripts in this project. Use these as building blocks.

---

## Session and identity

Always create a session with optional profile support. Always verify account identity before doing real work.

```python
# Python
session = boto3.Session(profile_name=args.profile) if args.profile else boto3.Session()
account_id = session.client("sts").get_caller_identity()["Account"]
print(f"Account: {account_id}", file=sys.stderr)
```

```javascript
// JavaScript — profile via AWS_PROFILE env var (SDK v3 reads it automatically)
// Print account to stderr
const { STSClient, GetCallerIdentityCommand } = require("@aws-sdk/client-sts");
const sts = new STSClient({ region: REGION });
const { Account } = await sts.send(new GetCallerIdentityCommand({}));
console.error(`Account: ${Account}`);
```

---

## Pagination — Python

Never assume a single API response is complete. Use paginators for every list operation.

```python
# CloudFront distributions
cf = session.client("cloudfront")
paginator = cf.get_paginator("list_distributions")
for page in paginator.paginate():
    for dist in page.get("DistributionList", {}).get("Items", []):
        print(dist["Id"], dist.get("Comment", ""))

# S3 objects
s3 = session.client("s3")
paginator = s3.get_paginator("list_objects_v2")
for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
    for obj in page.get("Contents", []):
        print(obj["Key"])

# CloudWatch log streams
logs = session.client("logs", region_name=region)
paginator = logs.get_paginator("filter_log_events")
for page in paginator.paginate(logGroupName=log_group, filterPattern=pattern):
    for event in page.get("events", []):
        print(event["message"])
```

---

## Pagination — JavaScript (AWS SDK v3)

```javascript
const { CloudFrontClient, ListDistributionsCommand } = require("@aws-sdk/client-cloudfront");
const cf = new CloudFrontClient({ region: "us-east-1" });

let marker;
const distributions = [];
do {
    const params = { MaxItems: "100" };
    if (marker) params.Marker = marker;
    const res = await cf.send(new ListDistributionsCommand(params));
    const list = res.DistributionList;
    distributions.push(...(list.Items || []));
    marker = list.IsTruncated ? list.NextMarker : undefined;
} while (marker);
```

---

## CloudFront — update with ETag

CloudFront requires the current ETag to update a distribution. Fetch it first.

```python
cf = session.client("cloudfront")
current = cf.get_distribution(Id=distribution_id)
etag = current["ETag"]
config = current["Distribution"]["DistributionConfig"]

# Make changes to config...

cf.update_distribution(
    Id=distribution_id,
    IfMatch=etag,
    DistributionConfig=config,
)
```

---

## Lambda@Edge — cross-region access

Lambda@Edge functions live in `us-east-1` but execute globally. Their ARNs tell you the region.

```python
def get_lambda_function(session, arn):
    # ARN format: arn:aws:lambda:REGION:ACCOUNT:function:NAME:VERSION
    region = arn.split(":")[3]
    lam = session.client("lambda", region_name=region)
    return lam.get_function(FunctionName=arn)
```

---

## S3 — read with depth limiting

For exploring large buckets, always limit depth and breadth to avoid runaway list operations.

```python
def list_prefix(s3, bucket, prefix, max_items=50):
    """List immediate children (both files and folders) under prefix."""
    paginator = s3.get_paginator("list_objects_v2")
    folders = []
    files = []
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix, Delimiter="/"):
        folders.extend(p["Prefix"] for p in page.get("CommonPrefixes", []))
        files.extend(o["Key"] for o in page.get("Contents", []))
        if len(folders) + len(files) >= max_items:
            break
    return folders[:max_items], files[:max_items]
```

---

## Athena — run and poll

Athena queries are async. Poll until done; raise on failure.

```python
import boto3, time

def run_athena_query(session, sql, database, workgroup, output_location):
    athena = session.client("athena")
    response = athena.start_query_execution(
        QueryString=sql,
        QueryExecutionContext={"Database": database},
        WorkGroup=workgroup,
        ResultConfiguration={"OutputLocation": output_location},
    )
    execution_id = response["QueryExecutionId"]

    while True:
        status = athena.get_query_execution(QueryExecutionId=execution_id)
        state = status["QueryExecution"]["Status"]["State"]
        if state == "SUCCEEDED":
            return execution_id
        if state in ("FAILED", "CANCELLED"):
            reason = status["QueryExecution"]["Status"]["StateChangeReason"]
            raise RuntimeError(f"Athena query {state}: {reason}")
        time.sleep(2)
```

---

## Error handling patterns

**Boto3 service exceptions** — catch by name, not by generic `Exception`:
```python
try:
    response = client.get_distribution(Id=dist_id)
except client.exceptions.NoSuchDistribution:
    print(f"Distribution {dist_id} not found", file=sys.stderr)
    sys.exit(1)
except client.exceptions.AccessDenied:
    print("Access denied — check your AWS profile has CloudFront read permissions", file=sys.stderr)
    sys.exit(1)
```

**Per-item errors in bulk operations** — don't let one failure kill the whole job:
```python
results = []
for item in items:
    try:
        results.append(process(session, item))
    except Exception as e:
        results.append({"id": item["id"], "error": str(e)})
```

---

## Output file naming convention

Scripts that save output use this pattern for consistent, non-conflicting filenames:

```python
from datetime import datetime

account_id = session.client("sts").get_caller_identity()["Account"]
timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
out_dir = f"output/{account_id}/{resource_id}"
os.makedirs(out_dir, exist_ok=True)
output_path = f"{out_dir}/{resource_id}_{timestamp}.json"
```

---

## CloudWatch Logs — filter by request ID

Finding Lambda@Edge log entries for a specific CloudFront request:

```python
def find_log_events(session, log_group, request_id, region, start_ms=None, end_ms=None):
    logs = session.client("logs", region_name=region)
    params = {
        "logGroupName": log_group,
        "filterPattern": f'"{request_id}"',
        "interleaved": True,
    }
    if start_ms:
        params["startTime"] = start_ms
    if end_ms:
        params["endTime"] = end_ms

    try:
        response = logs.filter_log_events(**params)
        return response["events"]
    except logs.exceptions.ResourceNotFoundException:
        return []
```

---

## Edge location to AWS region

Lambda@Edge logs land in the region closest to the edge location where the request was served. Map IATA codes to regions:

```python
IATA_TO_REGION = {
    "IAD": "us-east-1", "JFK": "us-east-1", "ATL": "us-east-1",
    "ORD": "us-east-2", "CMH": "us-east-2",
    "PDX": "us-west-2", "SEA": "us-west-2",
    "SFO": "us-west-1", "LAX": "us-west-1",
    "LHR": "eu-west-2", "DUB": "eu-west-1",
    "FRA": "eu-central-1", "CDG": "eu-west-3",
    "NRT": "ap-northeast-1", "SIN": "ap-southeast-1",
    "SYD": "ap-southeast-2", "BOM": "ap-south-1",
    "GRU": "sa-east-1",
}

def edge_to_region(edge_location):
    """e.g. 'IAD50-C1' -> 'us-east-1'. Falls back to us-east-1."""
    iata = edge_location[:3].upper()
    return IATA_TO_REGION.get(iata, "us-east-1")
```
