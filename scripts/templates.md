# Script Templates

Copy-paste starting points for new scripts. Pick the right template, fill in the blanks, delete unused sections.

---

## Python — AWS read-only script

For scripts that query AWS and output data (list, dump, fetch).

```python
#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "boto3",
# ]
# ///
"""
<One-line description of what this script does.>

Usage:
    uv run scripts/<script-name>.py <required-arg>
    uv run scripts/<script-name>.py <required-arg> -p my-aws-profile
    uv run scripts/<script-name>.py <required-arg> --json
"""
import argparse
import json
import sys

import boto3


def fetch_data(session, target):
    """Fetch <X> from AWS. Returns list of dicts."""
    client = session.client("<service>")
    paginator = client.get_paginator("<list_operation>")

    items = []
    for page in paginator.paginate():
        for item in page.get("<ResultKey>", {}).get("Items", []):
            items.append({
                "id": item["Id"],
                "name": item.get("Name", ""),
            })
    return items


def main():
    parser = argparse.ArgumentParser(description="<Description>")
    parser.add_argument("target", help="<What this arg is>")
    parser.add_argument("-p", "--profile", help="AWS profile to use")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    args = parser.parse_args()

    session = boto3.Session(profile_name=args.profile) if args.profile else boto3.Session()
    account_id = session.client("sts").get_caller_identity()["Account"]
    print(f"Account: {account_id}", file=sys.stderr)

    items = fetch_data(session, args.target)

    if args.json:
        print(json.dumps({"account": account_id, "items": items}, indent=2))
    else:
        print(f"\nFound {len(items)} item(s):\n")
        print(f"{'ID':<20} {'Name':<40}")
        print("-" * 60)
        for item in items:
            print(f"{item['id']:<20} {item['name']:<40}")


if __name__ == "__main__":
    main()
```

---

## Python — AWS write script (with dry-run)

For scripts that create, update, or delete AWS resources.

```python
#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "boto3",
# ]
# ///
"""
<One-line description.>

Usage:
    uv run scripts/<script-name>.py <resource-id>
    uv run scripts/<script-name>.py <resource-id> --dry-run
    uv run scripts/<script-name>.py <resource-id> -p my-aws-profile
"""
import argparse
import json
import sys

import boto3


def get_current_state(session, resource_id):
    """Fetch current state of <resource>. Returns dict."""
    client = session.client("<service>")
    response = client.get_<resource>(Id=resource_id)
    return response["<Resource>"]


def apply_change(session, resource_id, current, dry_run=False):
    """Apply <change> to <resource>. Returns True on success."""
    # Build the updated config from current state
    updated = {**current}
    # ... make changes to `updated` ...

    if dry_run:
        print("DRY RUN — would apply:")
        print(json.dumps(updated, indent=2, default=str))
        return True

    client = session.client("<service>")
    etag = current.get("ETag")  # Required for CloudFront updates
    client.update_<resource>(
        Id=resource_id,
        IfMatch=etag,
        <Resource>Config=updated["<ResourceConfig>"],
    )
    return True


def main():
    parser = argparse.ArgumentParser(description="<Description>")
    parser.add_argument("resource_id", help="<Resource> ID to update")
    parser.add_argument("-p", "--profile", help="AWS profile to use")
    parser.add_argument("--dry-run", action="store_true", help="Preview changes without applying")
    args = parser.parse_args()

    session = boto3.Session(profile_name=args.profile) if args.profile else boto3.Session()
    account_id = session.client("sts").get_caller_identity()["Account"]
    print(f"Account: {account_id}", file=sys.stderr)

    if args.dry_run:
        print("DRY RUN mode — no changes will be made")

    try:
        current = get_current_state(session, args.resource_id)
        success = apply_change(session, args.resource_id, current, dry_run=args.dry_run)
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
```

---

## Python — dump to JSON file

For scripts that pull data from AWS and save a backup/snapshot.

```python
#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "boto3",
# ]
# ///
"""
Dump <resource> config to JSON.

Usage:
    uv run scripts/<script-name>.py <id>
    uv run scripts/<script-name>.py <id> -p my-aws-profile
    uv run scripts/<script-name>.py <id> -o custom-output.json
"""
import argparse
import json
import os
import sys
from datetime import datetime

import boto3


def get_data(session, resource_id):
    """Fetch all data for <resource>. Returns serializable dict."""
    client = session.client("<service>")
    # ... fetch data ...
    return {}


def main():
    parser = argparse.ArgumentParser(description="Dump <resource> config to JSON")
    parser.add_argument("resource_id", help="<Resource> ID")
    parser.add_argument("-p", "--profile", help="AWS profile to use")
    parser.add_argument("-o", "--output", help="Output file path (default: auto-generated)")
    args = parser.parse_args()

    session = boto3.Session(profile_name=args.profile) if args.profile else boto3.Session()
    account_id = session.client("sts").get_caller_identity()["Account"]
    print(f"Account: {account_id}", file=sys.stderr)

    data = get_data(session, args.resource_id)

    if args.output:
        output_path = args.output
        out_dir = os.path.dirname(output_path)
        if out_dir:
            os.makedirs(out_dir, exist_ok=True)
    else:
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        out_dir = f"output/{account_id}"
        os.makedirs(out_dir, exist_ok=True)
        output_path = f"{out_dir}/{args.resource_id}_{timestamp}.json"

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False, default=str)

    print(f"Wrote to: {output_path}")


if __name__ == "__main__":
    main()
```

---

## JavaScript — AWS batch processing

For scripts that query AWS and process results concurrently.

```javascript
#!/usr/bin/env node
// <One-line description of what this script does.>
// Usage: node scripts/<script-name>.js
//        DAY=2026-03-22 node scripts/<script-name>.js

const { AthenaClient, StartQueryExecutionCommand, GetQueryExecutionCommand, GetQueryResultsCommand } = require("@aws-sdk/client-athena");

// --- Configuration ---
const REGION    = process.env.AWS_REGION || "us-east-1";
const DATABASE  = process.env.DATABASE;
const TABLE     = process.env.TABLE;
const DAY       = process.env.DAY;          // YYYY-MM-DD
const CONCURRENCY = 5;

// Validate required config at startup
for (const [name, val] of [["DATABASE", DATABASE], ["TABLE", TABLE], ["DAY", DAY]]) {
    if (!val) throw new Error(`${name} env var is required`);
}

const client = new AthenaClient({ region: REGION });

// --- Helpers ---

async function runQuery(sql) {
    const { QueryExecutionId } = await client.send(new StartQueryExecutionCommand({
        QueryString: sql,
        QueryExecutionContext: { Database: DATABASE },
        ResultConfiguration: { OutputLocation: process.env.ATHENA_OUTPUT },
    }));

    while (true) {
        const { QueryExecution } = await client.send(new GetQueryExecutionCommand({ QueryExecutionId }));
        const state = QueryExecution.Status.State;
        if (state === "SUCCEEDED") return QueryExecutionId;
        if (state === "FAILED" || state === "CANCELLED")
            throw new Error(`Query ${state}: ${QueryExecution.Status.StateChangeReason}`);
        await new Promise(r => setTimeout(r, 2000));
    }
}

async function fetchRows(queryExecutionId) {
    const rows = [];
    let nextToken;
    do {
        const params = { QueryExecutionId: queryExecutionId, MaxResults: 1000 };
        if (nextToken) params.NextToken = nextToken;
        const res = await client.send(new GetQueryResultsCommand(params));
        for (const row of res.ResultSet.Rows) rows.push(row.Data[0].VarCharValue);
        nextToken = res.NextToken;
    } while (nextToken);
    return rows.slice(1); // skip header row
}

// --- Main ---

async function main() {
    console.error(`Processing ${DAY}...`);

    const queryId = await runQuery(`
        SELECT DISTINCT id FROM "${DATABASE}"."${TABLE}"
        WHERE date_partition = '${DAY}'
        ORDER BY id
    `);
    const ids = await fetchRows(queryId);
    console.error(`Found ${ids.length} records`);

    let idx = 0;
    async function worker() {
        while (idx < ids.length) {
            const i = idx++;
            const id = ids[i];
            try {
                // Process id...
                console.error(`[${i + 1}/${ids.length}] ✓ ${id}`);
            } catch (err) {
                console.error(`[${i + 1}/${ids.length}] ✗ ${id}: ${err.message}`);
            }
        }
    }

    await Promise.all(Array.from({ length: CONCURRENCY }, worker));
    console.error("Done");
}

main().catch(err => { console.error(err); process.exit(1); });
```

---

## Bash — API fetch with token

For shell scripts that call an API with a bearer token.

```bash
#!/bin/bash
# Purpose: <One-line description>
# Input:   TOKEN (arg 1)
# Output:  output/result.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../../output"
OUTPUT_FILE="${OUTPUT_DIR}/result.json"

if [ $# -ne 1 ]; then
  echo "Usage: $0 <token>" >&2
  echo "Example: $0 'eyJ0eXAiOiJKV1QiLCJub25jZSI6...'" >&2
  exit 1
fi

TOKEN="$1"
BASE_URL="${API_BASE_URL:-https://api.example.com}"

mkdir -p "$OUTPUT_DIR"

echo "Fetching from $BASE_URL..." >&2

RESPONSE=$(curl -sf --max-time 30 \
  --url "${BASE_URL}/endpoint" \
  --header "Authorization: Bearer $TOKEN" \
  --header "Accept: application/json")

if ! echo "$RESPONSE" | jq empty 2>/dev/null; then
  echo "Error: Invalid JSON response" >&2
  echo "$RESPONSE" >&2
  exit 1
fi

echo "$RESPONSE" | jq '.' > "$OUTPUT_FILE"

echo "Saved to $OUTPUT_FILE" >&2
echo "Total: $(jq 'length' "$OUTPUT_FILE")" >&2
```
