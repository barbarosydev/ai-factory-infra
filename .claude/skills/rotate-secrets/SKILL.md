---
name: rotate-secrets
description: Rotate PostgreSQL database passwords or LiteLLM master and agent virtual keys without exposing plaintext in Git, Terraform state or chat. Use when asked to rotate credentials or after a suspected key leak.
---

# Rotate secrets (zero-plaintext workflow)

All credentials in `ai-factory-infra` are generated via `ephemeral "random_password"` and written to Kubernetes Secrets using write-only attributes (`data_wo` + `data_wo_revision`), so secret values are `null` in `terraform.tfstate`. Rotation is triggered by incrementing the version integer variable.

## 1. Rotate PostgreSQL role passwords (`temporal` & `litellm`)

1. Edit `variable "password_version"` default in `terraform/modules/postgres/variables.tf` (or pass `password_version` from `terraform/environments/local/main.tf`), incrementing the integer by `1`.
2. Run `task lint` and `task plan`: confirm only `module.postgres.kubernetes_secret_v1.db_user["litellm"]` and `module.postgres.kubernetes_secret_v1.db_user["temporal"]` show `~ data_wo_revision` updates.
3. Ask before running `task apply`.
4. After `task apply`:
   - CloudNativePG automatically reconciles the new password into PostgreSQL because the Secrets carry label `"cnpg.io/reload" = "true"`.
   - Restart LiteLLM and Temporal server deployments so their connection pools pick up the updated Secret:
     - `task kube -- rollout restart deployment/litellm -n ai-platform`
     - `task kube -- rollout restart deployment/temporal-frontend deployment/temporal-history deployment/temporal-matching deployment/temporal-worker -n ai-platform`
5. Verify with `task doctor -- --only postgres,litellm,temporal`.

## 2. Rotate LiteLLM master key and agent virtual keys (`pm-agent`, `dev-agent`, `sec-agent`)

1. Increment `variable "secret_version"` default in `terraform/modules/litellm/variables.tf` (e.g. `1` -> `2`).
2. Run `task lint` and `task plan`:
   - `kubernetes_secret_v1.master_key` and `kubernetes_secret_v1.agent_key[*]` update `data_wo_revision`.
   - `helm_release.litellm` updates the bootstrap Job name (`litellm-bootstrap-keys-v<N>`) so Kubernetes runs a fresh Job that updates each agent's virtual key via `/key/update`.
3. Ask before running `task apply`.
4. After `task apply`, restart `deployment/litellm` (`task kube -- rollout restart deployment/litellm -n ai-platform`) if the master key changed, then verify with `task doctor -- --only litellm`.

Never print or inspect the old or new secret values. Use `task access -- --copy <target>` when you need a rotated key in the macOS clipboard.
