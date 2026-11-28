# 0001. Scope and local platform architecture

## Status

Accepted (amended by [0008](0008-arize-phoenix-and-opentelemetry-observability.md))

## Date

2026-11-16

## Context

This repo builds the infrastructure that a future AI factory will run on, on one Apple Silicon Mac. It must run next to everyday macOS apps, and the Mac also holds real cloud kubeconfig contexts that must stay out of reach.

## Decision

- Scope: the repo provides the platform only (cluster, PostgreSQL, LiteLLM, Temporal, Arize Phoenix trace UI/receiver, Ollama access). It contains no factory agents, no cloud models and no cloud cluster.
- Docker Desktop is the container runtime. Its CPU, memory, swap and disk limits are set as a ceiling, and its built-in Kubernetes is off so there is only one cluster. `task doctor:prereqs` checks this.
- One k3d cluster, `ai-factory`, with a single k3s server. It is cheap to stop and start, and its volumes survive `task down`.
- Ollama runs natively on the Mac, because containers on macOS cannot use the Apple GPU. Pods reach it only through the `ollama` Service, which points at `host.k3d.internal`. Moving models elsewhere later changes only the `model-backend` module.
- The built-in Traefik ingress serves web pages on port 8080 under `*.localhost` names, which resolve to loopback without `/etc/hosts` edits. Temporal's gRPC port 7233 is published separately.
- Every published port is bound to `127.0.0.1`.

## Consequences

- Pods can reach Ollama without knowing where it runs.
- One command brings the whole platform up or down, with data kept.
- Sizing and measured memory use are documented in [architecture.md](../architecture.md).

### Known limitations

- After a stopped cluster resumes, pods cannot resolve `host.k3d.internal` for about 90 seconds. `scripts/cluster-setup.sh` waits for it.
- A Docker Desktop sign-in to an organization with registry rules can block image pulls. Probe pods therefore use the official `busybox` image, and `task doctor:prereqs` warns while signed in.
- Routing uses the Ingress API, not the Gateway API. Ingress is enough for three hostnames (`litellm`, `temporal`, `phoenix`).
- `curl` through a configured proxy needs `--noproxy '*'` for `*.localhost`.
- See the [runbook](../runbook.md) for fixes.
