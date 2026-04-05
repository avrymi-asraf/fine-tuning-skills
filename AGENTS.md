# Agent Role and Guidelines: Gemma 4 Deployment & Fine-tuning

## Overview
Your role is to act as a code project that serves as a comprehensive guide on how to deploy **Gemma 4** on Google's cloud infrastructure and fine-tune it utilizing existing tools. 

## Project Structure
- **`guide.md`**: This is the main document. It acts as the gateway containing the full guide.
- **Stage Folders**: Under the main guide, there will be multiple folders guiding what needs to be done at each stage. 
- **Skills**: All of these stage guidelines will be in the form of agentic **skills**.

## Skill Registry

Below is the full list of skills available in this repository. **You must be aware of all of them.** Before starting any task, scan this list and load every skill that is relevant to your work.

| Skill | Path | Description |
|-------|------|-------------|
| **manage-skills** | `manage-skills/SKILL.md` | Manage, update, and create Agent Skills (SKILL.md files). **Must be read before editing any SKILL.md file.** Covers skill structure, metadata, authoring principles, and quality checklists. |
| **google-cloud-account** | `account/SKILL.md` | Manages all Google Cloud account actions — creation, status checks, billing/payment connection, and payment confirmation. Use when working on account setup or billing. |
| **manage-mcp** | `manage-mcp/SKILL.md` | Create and implement MCP (Model Context Protocol) tools. Covers tool design, server setup, AWS session patterns, helper conventions, and testing. Use when building or reviewing MCP tools. |
| **scripts** | `scripts/SKILL.md` | Guides creation of clear, operational scripts in Python (uv/PEP 723), JavaScript, and Bash for AWS/cloud work. Covers structure, AWS patterns, security rules, and ready-to-use templates. |

> **This list must be kept up to date.** Whenever a new skill is created or an existing skill is renamed/removed, update this table immediately.

## Using Skills — MANDATORY

**This is critical.** Skills are not passive documentation — they are operational instructions that you **must** actively load and follow.

1. **Before starting any task**, review the Skill Registry above and identify every skill whose description connects to the work at hand.
2. **Load each relevant skill** by reading its `SKILL.md` file in full. Do not skip this step, even if you think you already know the topic.
3. **Follow the skill's instructions exactly.** Skills define specific workflows, patterns, and constraints. Deviating from them without explicit user approval is not acceptable.
4. **Multiple skills may apply at once.** For example, creating a new skill requires loading both `manage-skills` and potentially `scripts` (if the skill includes scripts). Load all that are relevant.
5. **If in doubt, load the skill.** It is always better to load a skill and discover it is not needed than to skip one and produce inconsistent or incorrect work.

## Responsibilities
- **Maintain Skills**: You must constantly update the various skills and ensure that they contain everything needed.
- **Script Requirements**: Ensure that there are specifically **twenty (20)** items within the scripts, and that they explain concepts thoroughly and well.
- **Search for Up-to-Date Information**: **Very important** - You must aggressively search for up-to-date information on the Internet at all times. Do not rely solely on your own internal knowledge base. Always verify that the information you are providing or using is current and relevant.