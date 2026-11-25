# Secrets

No secret reaches git, Terraform state or a Claude conversation. Four layers enforce that:

| Layer | Control | Enforced by |
| --- | --- | --- |
| 1. Fewer secrets | No external API keys. CloudNativePG generates the PostgreSQL superuser Secret inside the cluster. Terraform generates the database user passwords (`temporal`, `litellm`, `phoenix`), the LiteLLM master key (`litellm-masterkey`) and the per-agent LiteLLM virtual keys (`litellm-pm-agent-key`, `litellm-dev-agent-key`, `litellm-test-agent-key`, `litellm-sec-agent-key`) ephemerally and writes them only to Kubernetes Secrets | `terraform/modules/postgres/main.tf`, `terraform/modules/litellm/main.tf` |
| 2. Out of state | Every Terraform-managed Kubernetes Secret uses `ephemeral "random_password"` and `kubernetes_secret_v1` `data_wo` with `data_wo_revision`, so `data` and `data_wo` are `null` in `terraform.tfstate`. An in-cluster bootstrap Job registers each agent's virtual key with LiteLLM directly from the cluster Secret | `terraform/modules/postgres/main.tf`, `terraform/modules/litellm/main.tf` |
| 3. Out of git | `.gitignore` covers state, tfvars, `.env` and `.kube/`. gitleaks runs in pre-commit (`task ci -- --staged`) and in CI (`task ci`, whole history). GitHub secret scanning and push protection are not enabled for this public repository, so gitleaks is the active secret-scanning control; see [ADR 0005](adr/0005-security-secrets-and-cluster-isolation.md) | `.gitignore`, `scripts/ci.sh` |
| 4. Out of AI context | Claude Code is denied from reading state, tfvars, `.env` and kubeconfigs; `kube-guard.py` blocks commands that print them or Secret values; `secret-guard.sh` blocks writing secrets into files | `.claude/settings.json`, `.claude/hooks/kube-guard.py`, `.claude/hooks/secret-guard.sh` |

`task doctor` (suite `state`, also `task state:check`) verifies layer 2 on every run: it prints only the number of secret-shaped values in `terraform.tfstate` plus resource addresses and attribute names, never a value.

AI-specific controls:

- **One virtual key per agent.** `pm-agent`, `dev-agent`, `test-agent` and `sec-agent` each hold their own virtual key in `litellm-<agent>-key`, scoped strictly to `models: ["<agent>"]` and a budget (`max_budget: 100`).
- **Prompt logging is controlled by one variable (metadata-only by default).** `litellm_store_prompts` defaults to `false` (`turn_off_message_logging: true`, `store_prompts_in_spend_logs: false`) with 3-day retention so neither Phoenix nor LiteLLM stores raw prompt/response text by default; see [ADR 0004](adr/0004-model-gateway-and-agent-routes.md) and [ADR 0008](adr/0008-arize-phoenix-and-opentelemetry-observability.md). Set `litellm_store_prompts = true` in `terraform/environments/local/variables.tf` (or toggle **Logs -> Settings** in the Admin UI) when debugging prompts locally.
- **Scripts print secret names, never values.**
- If a secret leaks, follow "A secret leaked" in the [runbook](runbook.md).
