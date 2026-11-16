# ADR-0004: Native Ollama on macOS and Gemma 4 Model Selection

## Context

Linux containers running inside Docker Desktop's VM on macOS cannot access the Apple Silicon GPU (Metal). In addition, several model tags from early drafts (`qwen3.5-coder`) do not exist in the Ollama library or exceed comfortable memory limits alongside the cluster.

## Decision

1. Run **Ollama natively on macOS** (`127.0.0.1:11434`) and expose it inside the cluster through a Kubernetes `ExternalName` Service named `ollama` (`terraform/modules/model-backend`) pointing at `host.k3d.internal:11434`.
2. Route `pm-agent` to **`gemma4:12b`** (7.6 GB on disk) and both `dev-agent` and `sec-agent` to **`gemma4:e4b`** (9.5 GB on disk), configured through a single `model_routes` Terraform variable.

## Why

- Native macOS execution gives full Metal GPU acceleration.
- Addressing Ollama through the in-cluster `ollama` Service keeps LiteLLM decoupled from the host network; moving models to an in-cluster or remote GPU endpoint later only changes `terraform/modules/model-backend`.
- `gemma4:12b` and `gemma4:e4b` belong to the current Gemma 4 family and fit comfortably within the 36 GB Mac alongside the 2.63 GiB k3d cluster.

## Consequences

- `gemma4` models emit reasoning (`thinking`) tokens by default; completion probes use `max_tokens: 128` so responses include non-empty `content`.
- `task down` explicitly unloads loaded models (`keep_alive: 0`) so RAM returns to macOS immediately when stopping the stack.
