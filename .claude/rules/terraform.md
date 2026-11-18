---
paths:
  - "terraform/**"
---

# Terraform conventions

- Helm provider 3.x and Kubernetes provider 3.x syntax: `set` and `set_sensitive` are lists of objects, and `kubernetes {}` inside the helm provider is an attribute (`kubernetes = { ... }`). Older tutorials use the 2.x block syntax and fail to validate. Use the Terraform MCP server for current docs.
- Write-only Secrets: `kubernetes_secret_v1` in provider 3.5 uses `data_wo` and `data_wo_revision` (not `data_wo_version`), paired with `ephemeral "random_password"`, so secret values stay `null` in `terraform.tfstate`.
- Lockfile platforms: whenever providers change, run `terraform -chdir=terraform/environments/local providers lock -platform=darwin_arm64 -platform=linux_amd64 -platform=linux_arm64` so Linux CI and macOS stay in sync (`task lint` checks this).
- Each module has `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` and (when deploying a Helm chart) `values.yaml.tftpl`. Variables set `nullable = false` and `validation {}` blocks; Helm releases set `cleanup_on_fail = true` and `max_history = 5`; Kubernetes resources carry `app.kubernetes.io/part-of = "ai-factory"` and `app.kubernetes.io/managed-by = "terraform"` labels; `README.md` tables are generated with `terraform-docs` and checked by `task lint`.
- Providers read the project kubeconfig (`local.kubeconfig_path` in `providers.tf`) and `config_context = "k3d-ai-factory"`, never the default kubeconfig. `scripts/terraform.sh` sets `kubeconfig_path` to the stack home's `.kube/config`, so a git worktree reaches the same cluster; a validation rejects the global kubeconfig. When calling `terraform init -reconfigure`, pass `-backend-config="path=$TF_STATE_FILE"` only from a git worktree (when `TF_STATE_FILE` is outside `tf_dir`); passing it in the main checkout where `terraform.tfstate` is already the default causes Terraform's local backend to truncate the existing state file to 0 bytes.
- Tests and policies: each module has `tests/*.tftest.hcl` (mock providers, plan only); add a `run` block for a new validation, Helm value or Secret. Repo-wide conventions are Conftest rules in `policy/`. `task lint` runs both.
- Images are pinned as tag plus digest in `terraform/environments/local/variables.tf`, with validation. A bump goes through the `upgrade-version` skill.
