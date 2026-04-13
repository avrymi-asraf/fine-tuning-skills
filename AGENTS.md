# Fine-Tuning Skills Repository

This repository contains agentic skills for fine-tuning language models on Google Cloud Platform.

## My Role

I am a personal assistant dedicated to writing and maintaining these skills. My job is to ensure the skills are accurate, up-to-date, and comprehensive.

## Skills Registry

| Skill | Purpose | Prerequisites |
|-------|---------|---------------|
| `cloud-infrastructure-setup` | GCP infrastructure for ML: gcloud CLI, auth, projects, billing, APIs, IAM, env vars, cost controls, diagnostics | None |
| `cloud-job-orchestration` | Vertex AI custom training jobs: submission, GPU selection, Spot VMs, monitoring, cost estimation | `cloud-infrastructure-setup` |
| `google-cloud-compute-ml` | Deploy and run ML models on GCP compute: GPU VMs, SSH, file transfer, Unsloth setup | `cloud-infrastructure-setup` |
| `container-engineering` | Build optimized, reproducible GPU containers for ML training | `cloud-infrastructure-setup` |
| `cloud-storage-artifacts` | Manage ML artifacts on GCS: buckets, uploads, downloads, lifecycle, cleanup | `cloud-infrastructure-setup` |
| `ml-training-pipeline` | Fine-tune LLMs with TRL/PEFT/PyTorch: data prep, model loading, LoRA/QLoRA, SFTTrainer, OOM debugging | None |

## Repository Structure

```
fine-tuning-skills/
├── AGENTS.md                    # This file - skill registry and conventions
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
└── cloud-infrastructure-setup/  # Skill: GCP infrastructure setup
    ├── SKILL.md
    ├── scripts/
    │   ├── gcp_auth.sh          # Auth, ADC, service accounts, config profiles
    │   ├── gcp_projects.sh      # Projects, billing, APIs, quotas, full setup
    │   ├── gcp_iam.sh           # IAM roles, policy, custom roles, audit
    │   ├── gcp_diagnose.sh      # Account health diagnostics
    │   ├── setup-gcloud.sh      # One-shot gcloud install and setup
    │   ├── check-permissions.sh # Verify permissions
    │   └── set-env.sh           # Env var template
    └── references/
        ├── gcloud-cheat-sheet.md
        ├── iam-roles-reference.md
        ├── cost-management-guide.md
        ├── troubleshooting.md
        └── documentation-links.md
└── cloud-job-orchestration/     # Skill: Vertex AI job orchestration
    ├── SKILL.md
    ├── scripts/
    │   ├── submit-training-job.py
    │   ├── monitor-job.sh
    │   ├── handle-preemption.sh
    │   ├── cost-estimate.py
    │   └── example-job-config.yaml
    └── references/
        ├── gpu-machine-types.md
        ├── command-cheat-sheet.md
        └── documentation-links.md
└── cloud-storage-artifacts/      # Skill: GCS artifact management
    ├── SKILL.md
    ├── scripts/
    │   ├── setup-bucket.sh
    │   └── cleanup-old-runs.sh
    └── references/
        ├── cli-cheat-sheet.md
        ├── storage-classes.md
        └── documentation-links.md
└── ml-training-pipeline/         # Skill: LLM fine-tuning pipeline
    ├── SKILL.md
    ├── scripts/
    │   ├── train.py              # Main training script (LoRA/QLoRA)
    │   ├── prepare-dataset.py    # Dataset preprocessing
    │   ├── validate-model.py     # Inference validation
    │   └── config.yaml           # Config template
    └── references/
        ├── chat-templates.md
        ├── peft-patterns.md
        ├── oom-debugging.md
        ├── memory-optimization.md
        └── official-docs.md
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
I'ts very very importent to use the skills!!
