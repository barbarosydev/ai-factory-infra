# 0004. Model gateway and agent routes

## Status

Accepted

## Date

2026-11-16

## Context

Agents must call models through one gateway, without sharing a master key or reaching models meant for other agents. The models run in Ollama on the Mac, and the Mac must stay usable while the cluster runs.

## Decision

- LiteLLM is installed from its OCI Helm chart; the old Helm repository URL no longer works. It stores data in the `litellm` database and runs migrations without Helm hooks.
- Each agent (`pm-agent`, `dev-agent`, `sec-agent`) has one model route and one virtual key scoped to that route only. A key calling another agent's route gets HTTP 403.
- Routes are one Terraform variable, `model_routes`. Adding or changing one follows the `add-model-route` skill.
- Each key is a write-only Kubernetes Secret, registered with LiteLLM by an in-cluster bootstrap Job. Keys therefore never pass through Terraform state or terminal output.
- Prompt logging is on by default (`litellm_store_prompts`) so requests and responses can be read in the Admin UI. This is the owner's decision of 16 November 2026. It is safe because only local models are used, so prompts never leave the Mac. The variable can switch it to metadata only.
- Models are from the gemma4 family. The `qwen3.5-coder` tag does not exist in the Ollama library, and larger models do not fit beside the cluster.

## Consequences

- Per-agent keys give isolation and per-agent spend tracking.
- `task smoke:litellm` checks completions on every route and the cross-agent rejection.
- `task access -- --copy <target>` copies a key to the clipboard without printing it.

### Known limitations

- gemma4 models spend small token budgets on thinking and then return empty content. Probes must use a larger `max_tokens`.
- Cloud model routes are out of scope until API credit exists; see [0005](0005-security-secrets-and-cluster-isolation.md).
- Do not load models above roughly 10 GB while the cluster runs.
