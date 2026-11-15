# Secrets

> Stub. Phases 3 and 4 confirm the two features layers 1 and 2 rely on and complete this page.

No secret reaches git, Terraform state or a Claude conversation. Four layers enforce that:

| Layer | Control | Where |
| --- | --- | --- |
| 1. Fewer secrets | No external API keys. CloudNativePG generates database passwords inside the cluster. Only the LiteLLM master key is created by Terraform | phases 3, 4 |
| 2. Out of state | The master key uses Terraform write-only attributes, so it is not saved in state | phase 4 |
| 3. Out of git | `.gitignore` covers state, tfvars, `.env` and `.kube/`. gitleaks runs in pre-commit (`task ci -- --staged`) and in CI (`task ci`, whole history) | phase 1 |
| 4. Out of AI context | Claude Code is denied from reading state, tfvars, `.env` and kubeconfigs; `kube-guard.py` blocks commands that print them or Secret values; `secret-guard.sh` blocks writing secrets into files | phase 1 |

Rules for anything new:

- Generate secrets inside the cluster where possible. Otherwise pass them as write-only values.
- A future cloud key lives in the macOS Keychain and enters Terraform as an environment variable at run time. Never type it into a Claude conversation.
- Scripts print secret names, never values.
- If a secret leaks, follow "A secret leaked" in the [runbook](runbook.md).
