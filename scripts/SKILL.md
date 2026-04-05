---
name: scripts
description: Guides creation of clear, operational scripts in Python (uv/PEP 723) and JavaScript for AWS/CDN work. Covers script structure, AWS session patterns, shell best practices, security rules, and copy-paste templates. Use when writing or reviewing any operational script — especially anything touching AWS, CloudFront, S3, Lambda, or Athena.
---

# Scripts

Operational scripts here are short, single-purpose tools that do one thing well and are readable without explanation. This skill covers how to structure them, what patterns to follow, and what to avoid — for Python, JavaScript, and Bash.

Topics:
- [Core principles](#core-principles) — the four laws every script must follow
- [Python with uv](#python-with-uv) — PEP 723 inline deps, argparse, main()
- [JavaScript](#javascript) — AWS SDK v3, concurrency, config
- [Shell scripts](#shell-scripts) — bash safety, curl, jq
- [AWS patterns](#aws-patterns) — sessions, paginators, account identity
- [Security rules](#security-rules) — what never goes in code
- [Templates](templates.md) — complete copy-paste starting points
- [AWS reference](aws-patterns.md) — boto3/SDK patterns in depth

---

## Core principles

These four laws are non-negotiable. Every script must satisfy all four before it's considered done.

### 1. Clarity first
**The main logic must be obvious from reading the code — not from comments.**

Code that needs a comment to be understood is code that should be rewritten. Use names that say what a thing *is* and what a function *does*. If the flow requires mental effort to follow, restructure it.

- `distribution_id` not `did`. `fetch_lambda_code` not `get_data`. `print_progress()` not `pp`.
- A function named `get_lambda_arns(distribution)` needs no comment. `process(x)` needs many.
- Never use cryptic lambdas or abbreviations at module scope.

### 2. Structure: one central script, helpers only when they earn their place
**Write a single script. Add a helper function only if it makes the code more readable — not to avoid duplication.**

A helper that's called once and does something obvious adds indirection without value. Keep the logic in `main()` or at the top level until the script genuinely benefits from factoring it out.

- `main()` should read like a plain-English description of what the script does
- Extract a function when it has a clear name, a clear purpose, and makes `main()` easier to read
- Don't split code into helpers just because it's long — long and clear beats short and opaque

### 3. Simplicity: use the most basic tool that works
**Prefer stdlib and simple dependencies. Reach for heavier libraries only when the task explicitly requires them.**

AWS operations need `boto3`. Argument parsing needs `argparse`. JSON, os, sys, datetime — these are enough for most scripts. Adding `pandas`, `pydantic`, or a framework for a 100-line script is a sign the design is wrong.

- Python: `boto3` + stdlib covers almost everything
- JavaScript: `@aws-sdk/client-*` + Node builtins
- If you're installing more than 2–3 packages, question whether this should be a script at all

### 4. Operation: run it, understand it, trust it
**A script must be runnable in one command and self-explanatory at first glance.**

The header (docstring or comment block) must show exactly how to run the script. The output must confirm what account and region it's operating in. The exit code must reflect success or failure.

- One-command execution: `uv run scripts/my-script.py <arg>` or `node scripts/my-script.js`
- Header shows the run command with a realistic example — not just syntax
- Print account ID to stderr before doing anything in AWS
- `sys.exit(0)` on success, `sys.exit(1)` on failure — always

---

### Additional rules

- **One purpose.** If you can't describe the script in one sentence, split it.
- **Named arguments.** Use `-p/--profile`, `-o/--output` via argparse or env vars — never raw `sys.argv[1]`.
- **Informational output to stderr, data to stdout.** Account IDs, status, progress → `stderr`. JSON/CSV → stdout or file.
- **No hardcoded values.** No dates, account IDs, bucket names, regions, or URLs in code.

---

## Python with uv

All Python scripts run with `uv run`. Declare dependencies inline using PEP 723 — no requirements files, no virtualenv setup:

```python
#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "boto3",
# ]
# ///
"""
One-line description of what this script does.

Usage:
    uv run scripts/my-script.py <required-arg>
    uv run scripts/my-script.py <required-arg> -p my-aws-profile
    uv run scripts/my-script.py <required-arg> --json
"""
```

**File structure** (top to bottom):
1. Shebang + PEP 723 block
2. Module docstring with usage examples
3. Stdlib imports, blank line, third-party imports
4. Module-level constants (only for values that truly never change)
5. Pure helper functions — each does one thing, no side effects
6. `def main()` — arg parsing + orchestration, no business logic inline
7. `if __name__ == "__main__": main()`

**Standard AWS argument pattern:**
```python
parser = argparse.ArgumentParser(description="...")
parser.add_argument("-p", "--profile", help="AWS profile to use")
args = parser.parse_args()

session = boto3.Session(profile_name=args.profile) if args.profile else boto3.Session()
```

**Never use bare `except:`.** Always `except Exception as e:` or a specific exception class.

---

## JavaScript

Use AWS SDK v3 (`@aws-sdk/client-*`). Import only what you need.

```javascript
#!/usr/bin/env node
// One-line description of what this script does.
// Usage: node scripts/my-script.js
//        BUCKET=my-bucket node scripts/my-script.js

const { S3Client, ListObjectsV2Command } = require("@aws-sdk/client-s3");

// --- Configuration (all from env or args) ---
const REGION = process.env.AWS_REGION || "us-east-1";
const BUCKET = process.env.BUCKET;
if (!BUCKET) throw new Error("BUCKET env var required");

// --- Functions ---

// --- Entry point ---
async function main() { ... }

main().catch(err => { console.error(err); process.exit(1); });
```

**Rules:**
- All config from env vars — validated at startup, not buried in logic
- Status and progress → `console.error()`; data output → `console.log()`
- Use a `CONCURRENCY` constant (default 5) for parallel operations; run workers with `Promise.all`
- Prefer `async/await` over raw `.then()` chains for readability

---

## Shell scripts

```bash
#!/bin/bash
# Purpose: One-line description
# Input:   TOKEN (arg 1)
# Output:  jwks/project-list.txt

set -euo pipefail  # Always on — never comment this out

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -ne 1 ]; then
  echo "Usage: $0 <token>" >&2
  exit 1
fi

TOKEN="$1"
```

**Rules:**
- `set -euo pipefail` — always on, on line 3, never commented out
- Use `BASH_SOURCE` for script-relative path resolution, not `$0`
- Validate `$#` before using args; print usage to stderr on failure
- Add `--max-time 30` to every `curl` call
- Always validate JSON with `jq empty` before parsing it
- Tokens and secrets via env vars, not embedded in files
- Error messages to stderr: `echo "Error: ..." >&2`

---

## AWS patterns

See [aws-patterns.md](aws-patterns.md) for full reference. The essentials:

**Always print account ID to stderr before doing anything:**
```python
account_id = session.client("sts").get_caller_identity()["Account"]
print(f"Account: {account_id}", file=sys.stderr)
```

**Always paginate list operations:**
```python
paginator = cf.get_paginator("list_distributions")
for page in paginator.paginate():
    for dist in page.get("DistributionList", {}).get("Items", []):
        ...
```

**Region from ARN** (Lambda@Edge and cross-region resources):
```python
region = arn.split(":")[3]  # arn:aws:lambda:REGION:account:function:name
client = session.client("lambda", region_name=region)
```

**Catch specific boto3 exceptions:**
```python
except client.exceptions.ResourceNotFoundException:
    print(f"Resource not found in {region}")
```

---

## Security rules

Non-negotiable — flag any violation immediately:

1. **No credentials in code.** No tokens, secrets, passwords, API keys. Use `os.environ["VAR"]` or the AWS credential chain (`~/.aws/credentials`, IAM role, env vars).
2. **No account IDs hardcoded.** Resolve dynamically: `sts.get_caller_identity()["Account"]`.
3. **No bucket names, ARNs, or URLs as constants.** Pass via args or env vars.
4. **Tokens in CLI args are visible in `ps`.** For sensitive values, prefer env vars.
5. **No real tokens in template or example files.** Use `<YOUR_TOKEN_HERE>` as placeholder.

If you see a credential in existing code: stop, flag it to the user, and replace with env var before doing anything else.

---

## Summary Checklist

### Four laws (apply to every script)
- [ ] **Clarity**: logic is obvious without comments — names say what things are and do
- [ ] **Structure**: single script; helpers extracted only where they genuinely aid readability
- [ ] **Simplicity**: only stdlib + the minimum required packages (boto3, AWS SDK)
- [ ] **Operation**: one-command run, header shows a real usage example, account printed to stderr

### Python script
- [ ] PEP 723 block with `requires-python` and `dependencies`
- [ ] Module docstring with `uv run` usage example (realistic, not just syntax)
- [ ] `-p/--profile` arg + `boto3.Session(profile_name=...)` pattern
- [ ] Account ID printed to stderr before any AWS work
- [ ] Paginators used for all list operations
- [ ] No hardcoded credentials, IDs, dates, bucket names
- [ ] No bare `except:` — always `except Exception as e:` or specific class
- [ ] `sys.exit(0/1)` at all exit points

### JavaScript script
- [ ] Comment header with one-liner and usage (including env var example)
- [ ] All config from env vars; required ones validated at startup with clear error
- [ ] AWS SDK v3 with named command imports
- [ ] Status/progress to `console.error`, data to `console.log`
- [ ] `main().catch(err => { console.error(err); process.exit(1); })`

### Shell script
- [ ] `set -euo pipefail` on line 3 — active, never commented out
- [ ] Arg count validated; usage printed to stderr on failure
- [ ] All `curl` calls have `--max-time`
- [ ] JSON validated with `jq empty` before parsing
- [ ] No tokens or secrets embedded in file

### Security
- [ ] No secrets, tokens, or credentials in code
- [ ] No hardcoded account IDs
- [ ] No real tokens in example or template files
