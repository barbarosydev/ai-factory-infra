# 0008. Arize Phoenix observability and LiteLLM usage overview

## Status

Accepted (amends [0001](0001-scope-and-local-platform-architecture.md), [0003](0003-data-and-orchestration-services.md), and [0004](0004-model-gateway-and-agent-routes.md))

## Date

2026-11-25

## Context

`ai-factory` needs an LLM-aware trace waterfall from Temporal workflows through Python PydanticAI agent roles, tools, and model calls without deploying a heavyweight multi-container telemetry stack on a 36 GB Mac. Meanwhile, LiteLLM's built-in Admin UI (`/ui/usage/`, `/ui/logs/`) showed flat `$0` charts on local Ollama models and stored raw prompts indefinitely by default.

## Decision

- Deploy one digest-pinned **Arize Phoenix** (`arizephoenix/phoenix`) Deployment, Service (`:6006`), and Traefik Ingress (`http://phoenix.localhost:8080`) in `terraform/modules/observability`.
- **Licence clarity**: Arize Phoenix server is **source-available under Elastic License 2.0 (ELv2)**, not OSI open source (its OpenInference/OTel client packages are Apache-2.0). Self-hosting for local development and portfolio demonstration is permitted; this repo stays MIT and deploys only the upstream image by digest.
- **Database isolation**: Add a fourth database (`phoenix`) and non-superuser role (`phoenix`) to CloudNativePG (`terraform/modules/postgres`), restricted via `pg_hba` and wired via discrete `PHOENIX_POSTGRES_*` environment variables reading the write-only Kubernetes Secret (`ai-postgres-phoenix-credentials`).
- **Retention, auth, and air-gapped posture**: Configure `PHOENIX_DEFAULT_RETENTION_POLICY_DAYS=3` (Phoenix sweeps expired traces periodically, weekly by default, so 3 days means eligible for cleanup after 3 days), `PHOENIX_ENABLE_AUTH=false` behind k3d's `127.0.0.1:8080` loopback binding, and disable Phoenix telemetry, external CDN resources, model-cost auto-updates, agent assistant, and MCP server.
- **LiteLLM `/ui/usage/` & `/ui/logs/` without OTLP or Lens bloat**: Skip LiteLLM OTLP export and skip **LiteLLM Lens** (`/ui/lens/`, which requires a separate `BerriAI/lens` + ClickHouse + Keeper stack). Instead, set 3-day spend/tag retention (`maximum_spend_logs_retention_period: "3d"`), configure local reference token pricing (`model_info`) so `/ui/usage/` charts and virtual-key budgets populate meaningfully, attach OSS virtual-key metadata (`user_id: ai-factory`, `metadata: {"role": agent, "app": "ai-factory"}` — note that top-level `tags` on `/key/generate` and `/key/update` is Enterprise-gated with HTTP 403 in LiteLLM `1.109.1`, whereas dynamic per-request `x-litellm-tags` headers work in OSS), and default `litellm_store_prompts = false` (metadata-only by default; toggleable to `true` for local prompt debugging).

## Consequences

- `task up` provisions Phoenix alongside Postgres, LiteLLM, and Temporal and verifies real OTLP HTTP/protobuf span ingestion + REST query readback via `task smoke:observability` (`tests/smoke/observability.sh`).
- Zero secrets enter `terraform.tfstate`, and no extra OTel collector or ClickHouse cluster is added.

### Known limitations

- Loopback no-auth (`127.0.0.1:8080`) is a trusted-local-machine choice, not isolation against other local processes or cluster pods.
- Three-day trace retention is shorter than `ai-factory`'s 7-day human clarification timeout, and cleanup runs on Phoenix's periodic sweep rather than at the exact 72-hour mark.
