# Secrets

> Phase 3 confirmed `ephemeral "random_password"` + `kubernetes_secret_v1` `data_wo` for database users. Phase 4 will confirm write-only Secret handling for the LiteLLM master key and complete this page.

No secret reaches git, Terraform state or a Claude conversation. Four layers enforce that:

| Layer | Control | Where |
| --- | --- | --- |
| 1. Fewer secrets | No external API keys. CloudNativePG generates the superuser secret inside the cluster; database user passwords (`temporal`, `litellm`) are generated ephemerally by Terraform and written only to Kubernetes Secrets (CloudNativePG's inline `managed.roles` requires pre-existing Secrets). Only the LiteLLM master key remains in phase 4 | phases 3, 4 |
| 2. Out of state | Database user Secrets use `ephemeral "random_password"` and `kubernetes_secret_v1` `data_wo` with `data_wo_revision`, so passwords are never saved in `terraform.tfstate`. The LiteLLM master key will follow the same pattern | phases 3, 4 |
| 3. Out of git | `.gitignore` covers state, tfvars, `.env` and `.kube/`. gitleaks runs in pre-commit (`task ci -- --staged`) and in CI (`task ci`, whole history). GitHub secret scanning and push protection are turned on when the repo goes public (free for public repos) | phase 1 |
| 4. Out of AI context | Claude Code is denied from reading state, tfvars, `.env` and kubeconfigs; `kube-guard.py` blocks commands that print them or Secret values; `secret-guard.sh` blocks writing secrets into files | phase 1 |

Rules for anything new:

- Generate secrets inside the cluster where possible. Otherwise pass them as write-only values (`data_wo`).
- A future cloud key lives in the macOS Keychain and enters Terraform as an environment variable at run time. Never type it into a Claude conversation.
- Scripts print secret names, never values.
- If a secret leaks, follow "A secret leaked" in the [runbook](runbook.md).
