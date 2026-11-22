# 0005. Security: secrets and cluster isolation

## Status

Accepted

## Date

2026-11-16

## Context

In a repo worked on with an AI assistant, a secret can leak into a git commit, into Terraform state or into the assistant's conversation. The Mac's global kubeconfig also holds real AKS contexts that no command here may touch.

## Decision

- No external API keys in this local sandbox. Only local models are used, so there is little to protect.
- Four independent layers, detailed in [secrets.md](../secrets.md):
  - Fewer secrets: generate them in the cluster or in Terraform, never by hand.
  - Out of state: `ephemeral "random_password"` with `kubernetes_secret_v1` `data_wo` and `data_wo_revision`, so values are `null` in state. Rotation bumps the revision.
  - Out of git: `.gitignore` for state, tfvars, `.env` and `.kube/`, plus gitleaks in pre-commit and CI.
  - Out of AI context: deny rules and hooks that block reading state, kubeconfigs and Secret values, and writing keys into files (see [0006](0006-agent-harness.md)).
- The cluster kubeconfig is stored only at `.kube/config` in the repo, and k3d never writes to the global one. Scripts, Terraform providers and `task kube` read only that file. The real AKS contexts are therefore unreachable, and lifecycle scripts fail if the global file changes.
- Database passwords come from Terraform as write-only values, not from CloudNativePG, so one mechanism covers every secret.
- The LiteLLM bootstrap Job inspects virtual keys via `Authorization: Bearer <key>` on `/key/info` rather than URL query parameters (`?key=...`), keeping virtual keys out of HTTP access logs.
- Public repository governance files (`LICENSE`, `SECURITY.md`, `.github/CODEOWNERS`) are committed and enforced by `scripts/lint.sh`.

## Consequences

- One mistake is stopped by another layer.
- Operators read secrets by name or copy them to the clipboard.

### Known limitations

- GitHub secret scanning and push protection are off while the repo is private. Branch protection is not available on the current plan. gitleaks and the branch-guard hook cover the gap.
- A future cloud key would live in the macOS Keychain and enter Terraform as an environment variable at run time, never in a conversation.
