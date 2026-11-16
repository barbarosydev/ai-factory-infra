# ADR-0009: Four-Layer Secret Management and Write-Only Attributes

## Context

In AI-assisted infrastructure repositories, secrets can leak not only into Git commits, but also into `terraform.tfstate` or an AI coding assistant's conversation context.

## Decision

Enforce four independent layers of secret protection (`docs/secrets.md`):
1. **Fewer secrets:** Use local Ollama models with no external cloud API keys during the sandbox phase.
2. **Out of Terraform state:** Pair `ephemeral "random_password"` with `kubernetes_secret_v1` write-only attributes (`data_wo` and `data_wo_revision` in `hashicorp/kubernetes` `3.5.0`) so secret values are sent to the Kubernetes API server and stored as `null` in `terraform.tfstate`.
3. **Out of Git:** `.gitignore` excludes state, `.tfvars`, `.env`, and `.kube/` from the first commit; `gitleaks` scans staged files in `pre-commit` and the entire commit history in `task ci` and GitHub Actions.
4. **Out of AI context:** `.claude/settings.json` denies reading state, `.tfvars`, `.env`, and kubeconfigs, and `.claude/hooks/kube-guard.py` + `secret-guard.sh` block printing Kubernetes Secret values or writing keys into files.

## Why

- Defense-in-depth ensures that a single mistake (e.g. an agent attempting to inspect a Secret or state file) is deterministically blocked by a hook before execution.
- `data_wo` + `ephemeral "random_password"` eliminates plaintext passwords from `terraform.tfstate` while remaining 100% declarative and rotatable via `secret_version`.

## Consequences

- Operators copy secrets to the macOS clipboard via `task access -- --copy <target>` without printing values to the terminal.
