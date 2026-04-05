---
name: manage-skills
description: Manage, update and create Agent Skills (SKILL.md files). MUST be read before editing any SKILL.md file. Use when the user asks to update, modify, fix, create, improve, or review any skill — even if they point directly to the skill file path.
---
# Managing Agent Skills

**STOP — Read this skill before editing any SKILL.md.** Even if the user gives you the file path directly, do NOT just open and edit it. Follow the workflow in this skill to maintain quality and consistency.

Skills are markdown files that teach agents how to perform specific tasks. This skill guides you through creating and updating them.

## Understanding the Skill

Before making changes, make sure you understand:

1. **Purpose and scope**: What tasks does this skill help with?
2. **Key domain knowledge**: What domain knowledge is required?
3. **Trigger scenarios**: When should the agent automatically apply this skill?
4. **Target location**: Personal (`~/.cursor/skills/`) or project (`.cursor/skills/`)?

If unsure, verify with the user. Use AskQuestion when available.

---

## Skill File Structure

### Directory Layout

```
skill-name/
├── SKILL.md              # Required - main instructions
├── reference.md          # Optional - detailed documentation
├── examples.md           # Optional - usage examples
└── scripts/              # Optional - utility scripts
```

### Storage Locations

| Type | Path | Scope |
|------|------|-------|
| Personal | ~/.cursor/skills/skill-name/ | Available across all your projects |
| Project | .cl/skills/skill-name/ | Shared with anyone using the repository |


### SKILL.md Structure

Every skill requires a `SKILL.md` with YAML frontmatter and markdown body:

```markdown
---
name: your-skill-name
description: Brief description of what this skill does and when to use it
---

# Your Skill Name
A broad introduction to the skill domain: what it covers, why it matters,
and links to each topic that follows in this skill and its reference files.

## <topic section>

## Examples
Concrete examples of using this skill's tools and workflows.
```

**The opening section is the most important part of the skill.** An agent reads the first ~50–80 lines before deciding how to proceed — and may not read further if the opening doesn't give it enough to work with. The opening section must:

- Explain the full domain: what this skill covers, why it exists, and how all the pieces relate
- Give enough context that the agent can act correctly on the most common tasks without reading anything else
- Link explicitly to every subsequent topic and reference file so the agent knows where to look

If the opening section is weak, the rest of the skill may never be used. Write it last, once you know the whole skill.

### Required Metadata

| Field | Requirements | Purpose |
|-------|--------------|---------|
| `name` | Max 64 chars, lowercase letters/numbers/hyphens | Unique identifier |
| `description` | Max 1024 chars, non-empty | Helps agent decide when to apply the skill |

Use [Common Patterns](Common Patterns.md) for writing patterns.

---

## Writing Effective Descriptions

The description is **critical** — the agent uses it to decide when to apply the skill.

1. **Write in third person** (injected into system prompt):
   - Good: "Processes Excel files and generates reports"
   - Bad: "I can help you process Excel files"

2. **Be specific and include trigger terms**:
   - Good: "Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction."
   - Bad: "Helps with documents"

3. **Include both WHAT and WHEN**:
   - WHAT: What the skill does (specific capabilities)
   - WHEN: When the agent should use it (trigger scenarios)

---

## Core Authoring Principles

### 1. Concise is Key

The context window is shared. Every token competes for space. The agent is already smart — only add context it doesn't have.

### 2. Progressive Disclosure

**SKILL.md must be under 300 lines.** Put essentials in SKILL.md; detailed reference in separate files read on demand. Keep references one level deep.

**SKILL.md ↔ reference file relationship**: The SKILL.md must explain each topic it covers well enough for the agent to act on it — references supplement, they don't replace. Each reference file must be focused on exactly one topic: it is a reference collection, not a secondary SKILL.md. Keep reference files short and specific. If a reference file is growing long or covering multiple concerns, split it or fold the essential parts back into SKILL.md.

### 3. Set Appropriate Degrees of Freedom

| Freedom Level | When to Use | Example |
|---------------|-------------|---------|
| **High** (text) | Multiple valid approaches | Code review guidelines |
| **Medium** (templates) | Preferred pattern with variation | Report generation |
| **Low** (specific scripts) | Fragile, consistency critical | Database migrations |

### 4. Use Scripts for Automation

When a skill needs automation or tooling, use scripts — not MCP. Scripts are explicit, portable, and easy to audit. Place them in `scripts/` and invoke them from the skill instructions.

See the [scripts skill](../scripts/SKILL.md) for how to write and structure auxiliary scripts correctly.

---

## Anti-Patterns

- **Windows paths**: Use `scripts/helper.py`, not `scripts\helper.py`
- **Too many options**: Provide one default approach, mention alternatives only when clearly needed
- **Time-sensitive info**: Use "Current method" / "Old patterns (deprecated)" sections
- **Inconsistent terminology**: Pick one term and use it throughout
- **Vague names**: Use `processing-pdfs`, not `helper` or `utils`

---

## Creating a New Skill

1. **Discovery**: Gather purpose, location, triggers, constraints, existing patterns
2. **Design**: Draft name, write description (with WHAT + WHEN), outline sections, identify supporting files
3. **Implement**: Create directory, write SKILL.md with frontmatter, create supporting files
4. **Verify**: Run the checklist below

---

## Updating an Existing Skill

When updating, the most important thing is **keeping consistency and quality**.

1. **Read the full skill first** — understand its structure, style, and voice
2. **Identify the root cause** — don't pile on fixes and warnings. Determine what's fundamentally wrong and fix that
3. **Integrate changes naturally** — new content must match the existing style and flow. Do NOT add a separate "rules" or "warnings" section
4. **Stay under 300 lines** — if adding content, trim elsewhere
5. **Verify**: Run the checklist below

---

## Verifying Processes

When a skill describes a process or workflow, **you must verify it yourself** before finalising. Do not assume a process is correct just because it was written — go through every step and confirm it works end-to-end.

1. **Walk through each step** — simulate or execute the process as the agent would. Don't just read it; follow it.
2. **Check for gaps** — are there steps that assume knowledge not stated in the skill? Fill them in.
3. **Check for errors** — does each step produce the expected output for the next step?
4. **Check for clarity** — would an agent unfamiliar with the domain understand every instruction? Rewrite anything ambiguous.
5. **Fix issues in place** — don't add a warning note. Correct the process directly so it is accurate and clear.

---

## Summary Checklist

### Core Quality
- [ ] Description is specific and includes trigger terms (both WHAT and WHEN)
- [ ] Written in third person
- [ ] SKILL.md is under 300 lines
- [ ] Consistent terminology throughout
- [ ] Examples are concrete, not abstract

### Structure
- [ ] Opening section is a broad intro with links to all topics and reference files
- [ ] Each reference file covers exactly one topic — concise, not a second SKILL.md
- [ ] File references are one level deep
- [ ] Progressive disclosure used appropriately
- [ ] Scripts used for automation (not MCP)
- [ ] Workflows have clear steps
- [ ] Processes have been walked through and verified end-to-end

### Update-Specific
- [ ] Read the full existing skill before editing
- [ ] Changes match existing style and voice
- [ ] No "pile of fixes" — root cause addressed
- [ ] New content integrated into existing sections
