# ADR-0006: LiteLLM OCI Chart, Prompt Storage, and Per-Agent Virtual Keys

## Context

LiteLLM's legacy GitHub Pages Helm repository URL returns 404; official charts now ship via OCI (`oci://ghcr.io/berriai/litellm-helm`). Agents (`pm-agent`, `dev-agent`, `sec-agent`) should never share a master key or hold unrestricted access to all models.

## Decision

- Deploy `oci://ghcr.io/berriai/litellm-helm` version **`1.109.1`** in `terraform/modules/litellm` backed by the `litellm` PostgreSQL database (`useHelmHooks: false` on database migrations).
- Enable `store_prompts_in_spend_logs = true` (`litellm_store_prompts` variable) so request/response payloads can be inspected in the LiteLLM Admin UI (`/ui`).
- Generate one write-only Kubernetes Secret per agent (`litellm-pm-agent-key`, `litellm-dev-agent-key`, `litellm-sec-agent-key`) and register each key idempotently via an in-cluster bootstrap Job (`litellm-bootstrap-keys-v1`) scoped strictly to its own model route (`models: [agent]`).

## Why

- Per-agent virtual keys enforce model-route isolation (e.g. `pm-agent`'s key is rejected with HTTP `403` when calling `dev-agent`) and per-agent spend tracking.
- Provisioning keys inside an in-cluster Job that reads write-only Kubernetes Secrets means virtual keys never pass through Terraform state or terminal stdout.

## Consequences

- `task access -- --copy <master|pm-agent|dev-agent|sec-agent>` copies keys directly from the cluster Secret to the macOS clipboard without printing them.
- `task smoke:litellm` tests completions for all three agent routes and verifies cross-agent HTTP `403` rejection.
