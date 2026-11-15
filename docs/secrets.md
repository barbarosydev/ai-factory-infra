# Secrets

No secret reaches git, Terraform state or a Claude conversation. Four layers enforce that:

| Layer | Control | Where |
| --- | --- | --- |
| 1. Fewer secrets | No external API keys. CloudNativePG generates the superuser secret inside the cluster; database user passwords (`temporal`, `litellm`), the LiteLLM master key (`litellm-masterkey`), and per-agent LiteLLM virtual keys (`litellm-pm-agent-key`, `litellm-dev-agent-key`, `litellm-sec-agent-key`) are generated ephemerally by Terraform and written only to Kubernetes Secrets | phases 3, 4 |
| 2. Out of state | Every Terraform-managed Kubernetes Secret uses `ephemeral "random_password"` and `kubernetes_secret_v1` `data_wo` with `data_wo_revision`, so `data` and `data_wo` are `null` in `terraform.tfstate`. An in-cluster bootstrap Job registers each agent's virtual key with LiteLLM directly from the cluster Secret | phases 3, 4 |
| 3. Out of git | `.gitignore` covers state, tfvars, `.env` and `.kube/`. gitleaks runs in pre-commit (`task ci -- --staged`) and in CI (`task ci`, whole history). GitHub secret scanning and push protection are turned on when the repo goes public (free for public repos) | phase 1 |
| 4. Out of AI context | Claude Code is denied from reading state, tfvars, `.env` and kubeconfigs; `kube-guard.py` blocks commands that print them or Secret values; `secret-guard.sh` blocks writing secrets into files | phase 1 |

AI-specific controls:

- **One virtual key per agent.** `pm-agent`, `dev-agent` and `sec-agent` each hold their own virtual key in `litellm-<agent>-key`, scoped strictly to `models: ["<agent>"]` and a budget (`max_budget: 100`).
- **Prompts are not logged.** LiteLLM runs with `turn_off_message_logging: true` and `store_prompts_in_spend_logs: false`, storing request metadata only.
- **Keys enter at run time, not through files or chat.** A future cloud key lives in the macOS Keychain and enters Terraform as an environment variable at run time. Never type it into a Claude conversation.
- **Scripts print secret names, never values.**
- If a secret leaks, follow "A secret leaked" in the [runbook](runbook.md).
