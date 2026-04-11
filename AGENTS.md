# Fine-Tuning Skills Repository

This repository contains agentic skills for fine-tuning language models on Google Cloud Platform.

## My Role

I am a personal assistant dedicated to writing and maintaining these skills. My job is to ensure the skills are accurate, up-to-date, and comprehensive.

## Skills Registry

| Skill | Purpose | Prerequisites |
|-------|---------|---------------|
| `google-cloud-account` | GCP account setup: auth, billing, IAM, APIs, quotas | None |
| `google-cloud-compute-ml` | Deploy and run ML models on GCP compute: GPU VMs, SSH, file transfer, Unsloth setup | `google-cloud-account` |
| `container-engineering` | Build optimized, reproducible GPU containers for ML training | `google-cloud-account` |

## Repository Structure

```
fine-tuning-skills/
├── AGENTS.md                    # This file - skill registry and conventions
├── google-cloud-account/        # Skill: GCP account management
│   ├── SKILL.md
│   ├── reference.md
│   └── scripts/
│       ├── gcp_auth.sh
│       ├── gcp_projects.sh
│       ├── gcp_iam.sh
│       └── gcp_diagnose.sh
└── google-cloud-compute-ml/     # Skill: ML compute deployment
    ├── SKILL.md
    ├── reference.md
    ├── scripts/
    │   ├── gcp_compute.sh       # VM lifecycle
    │   ├── gcp_ssh.sh           # SSH connectivity
    │   ├── gcp_transfer.sh      # File transfer
    │   ├── gcp_setup.sh         # Environment setup
    │   ├── gcp_gemma.sh         # Gemma-specific workflows
    │   ├── gcp_workbench.sh     # Vertex AI Workbench
    │   └── gcp_cost.sh          # Cost management
    └── terraform/
        └── gemma-gpu-vm/        # Terraform module for GPU VMs
            ├── main.tf
            ├── variables.tf
            ├── outputs.tf
            ├── README.md
            ├── terraform.tfvars.example
            └── modules/
                └── gemma-gpu-vm/
                    ├── main.tf
                    ├── variables.tf
                    └── outputs.tf
└── container-engineering/       # Skill: ML container optimization
    ├── SKILL.md
    ├── README.md
    └── scripts/
        ├── build-and-push.sh    
        ├── test-container-locally.sh
        └── validate-cuda.sh
```

## Skill Conventions

1. **Prerequisites are explicit** — Each skill lists what must be done first
2. **Scripts are self-documenting** — Run without arguments to see usage
3. **Gap-free workflow** — Skills chain together without missing steps
4. **Current best practices** — Use web search to verify current approaches
5. **Cost awareness** — Always include cost management guidance

## Future Skills (Planned)

- `data-pipeline` — Data preparation and preprocessing
- `training-workflow` — Training orchestration and monitoring
- `model-serving` — Production model deployment
- `mlops` — CI/CD for ML models

---

*I maintain this repository. If you find issues or want new capabilities, let me know.*

## General Agent Skills

**IMPORTANT:** The agent MUST ALWAYS use the external skills located in `/home/avreymi/code/dotfiles/skills`.

| Skill Description | Skill Path |
|-------------------|------------|
| Parse and interpret `.chatreplay.json` files (captures the full agentic session) | `/home/avreymi/code/dotfiles/skills/chatreplay` |
| Jira workflow — read, search, create, and update issues, commit with ticket references | `/home/avreymi/code/dotfiles/skills/jira-workflow` |
| Create and implement MCP tools for CDN management | `/home/avreymi/code/dotfiles/skills/manage-mcp` |
| Update, create, fix or improve Agent Skills (SKILL.md files) | `/home/avreymi/code/dotfiles/skills/manage-skills` |
| Guides creation of clear, operational scripts in Python and JavaScript for AWS/CDN work | `/home/avreymi/code/dotfiles/skills/scripts` |
