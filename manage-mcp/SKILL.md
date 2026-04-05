---
name: manage-mcp
description: Create and implement MCP tools for CDN management — write new tools, add MCP capabilities to existing skills, design tools around simple focused tasks. Use when implementing MCP in a skill, creating new MCP tools, adding tool methods to mcp, planning tool structure, or designing tool workflows.
---

# Writing MCP Tools

MCP (Model Context Protocol) tools provide specialized capabilities for agents. This skill guides writing tools that are simple, clear, and maintainable.

## Core Principles

**Clarity first** — The logic should be obvious from code, not comments. If someone needs to change the tool, they should immediately understand what it does and where.

**Simplicity** — Prefer standard libraries and boto3 over complex dependencies.

**Helpers only for readability** — Avoid unnecessary abstractions. Each helper should make the code genuinely easier to understand. Keep them one level deep.

**One tool, one job** — Each tool solves one focused problem. Don't combine list, get, update, and delete into a single tool.

## File Format

Always write the MCP server as a `uv` script with inline metadata:

```python
#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "mcp[cli]>=1.2.0",
#     "boto3",
# ]
# ///
```

Keep dependencies minimal — prefer Python standard library first, add third-party packages only when clearly needed.

## Server Setup

Define a single FastMCP server with clear instructions:

```python
mcp = FastMCP(
    "cdn",
    instructions=(
        "CDN management tools for AWS CloudFront distributions. "
        "All tools accept an optional 'profile' parameter for the AWS profile name "
        "(e.g. 'CDN_DEV', 'CDN_MFK120'). If omitted, the default AWS credentials are used. "
        "The user must have active AWS credentials before calling any tool."
    ),
)
```

## Tool Design

### Focused Tools

Each tool should solve one focused problem:

**Good**: `list_distributions` — list all CloudFront distributions
**Good**: `get_distribution_data` — get full config + Lambda@Edge code
**Bad**: `manage_everything` — does listing, getting, updating, deleting

### Clear Parameters and Docstrings

```python
@mcp.tool()
def get_distribution_data(
    distribution_id: str | None = None,
    name: str | None = None,
    return_key: str | None = None,
    output: str | None = None,
    base_folder: str | None = None,
    readable_output: bool = True,
    profile: str | None = None,
) -> str:
    """Get CloudFront distribution config and Lambda@Edge code.

    Args:
        distribution_id: CloudFront distribution ID (e.g. "E2WLVHG64ESA3T")
        name: Terraform name to search by (e.g. "dev1")
        return_key: Dot-separated key to extract (e.g. "cdns.lambda_functions")
        output: Output file path (overrides base_folder)
        base_folder: Directory for automatic backup naming
        readable_output: Format UTF-8 Lambda content as readable lines
        profile: AWS profile name
    """
```

Rules:
- All tools return `str` — JSON or plain text, never raw Python objects
- Only include parameters the tool actually uses
- Use `str | None = None` for optional parameters

### Explicit Error Handling

Return clear error strings — no exceptions leaking to the caller:

```python
if not distribution_id and not name:
    return "Error: provide either distribution_id or name"

try:
    with open(backup_file, "r") as f:
        backup = json.load(f)
except FileNotFoundError:
    return f"Error: file not found: {backup_file}"
except json.JSONDecodeError as e:
    return f"Error: invalid JSON: {e}"
```

## Dealing with AWS Actions

When writing tools that interact with AWS (e.g., using `boto3`), always follow these rules:

1. **Accept an optional `profile` parameter**: Every MCP tool that interacts with AWS must accept `profile: str | None = None`. This allows users to switch between different AWS environments.
2. **Document the parameter**: In the tool's docstring, include `profile: AWS profile name` or `profile: AWS profile name (e.g. "CDN_DEV"). Uses default credentials if omitted.`
3. **Use the `_session` helper**: Initialize the `boto3.Session` inside the tool using `session = _session(profile)`.
4. **Pass `session` to domain helpers**: Pass the `session` object to focused helper functions (e.g., `_fetch_distribution(session, id)`), and let the helper call `session.client(...)`.

Example:
```python
@mcp.tool()
def list_distributions(profile: str | None = None) -> str:
    """List all CloudFront distributions.

    Args:
        profile: AWS profile name
    """
    session = _session(profile)
    # Let helpers use the session
    try:
        cf = session.client("cloudfront")
        # ... perform action ...
    except Exception as e:
        return f"Error: {str(e)}"
```

## Helper Functions

Helpers encapsulate repeated logic. Each has one job:

```python
# ── AWS Session ──────────────────────────────────────────────────────────────

def _session(profile: str | None = None) -> boto3.Session:
    return boto3.Session(profile_name=profile) if profile else boto3.Session()

# ── CloudFront Helpers ───────────────────────────────────────────────────────

def _fetch_distribution(session: boto3.Session, distribution_id: str) -> dict:
    cf = session.client("cloudfront")
    dist = cf.get_distribution(Id=distribution_id)
    tags = cf.list_tags_for_resource(Resource=dist["Distribution"]["ARN"])
    return {
        "distribution": dist["Distribution"],
        "tags": tags.get("Tags", {}).get("Items", []),
    }
```

Prefix private helpers with `_`. Group them with section headers matching the `# ── Name ──` pattern.

## Code Organization

Organize the file in this order:

```
1. Shebang + uv metadata
2. Imports
3. FastMCP server definition
4. Shared helpers (session, fetch, format)
5. Domain-specific helpers (grouped with ── section headers)
6. MCP tools (grouped by domain with ═══ section headers)
7. Entry point: if __name__ == "__main__": mcp.run()
```

Tool sections use double-line headers:

```python
# ═════════════════════════════════════════════════════════════════════════════
#  MCP Tools: CloudFront
# ═════════════════════════════════════════════════════════════════════════════

@mcp.tool()
def list_distributions(...) -> str:
    ...
```

## Testing

Do not start MCP servers just to test. Confirm the user has started the server first. If not, provide the command they should run and wait.

## Design Workflow

1. **Identify the tasks** — What operations does the domain need? (list, get, update, backup)
2. **One tool per operation** — Keep each tool focused on a single task
3. **Extract common logic** — Define helpers for session setup, data fetching, formatting
4. **Keep tool functions simple** — They call helpers, handle parameters, return JSON
5. **Document clearly** — Docstrings explain what each tool does and what parameters it needs

## What NOT to Do

- Don't add parameters "just in case" — only include what the tool actually uses
- Don't nest helpers deeply — one level max
- Don't mix concerns in one tool — listing and updating shouldn't share a tool
- Don't create tools for trivial operations that a direct API call can handle
