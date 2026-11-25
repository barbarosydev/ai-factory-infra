# 0009. Kubernetes NetworkPolicies and zero-trust pod isolation

## Status

Accepted (amends [0005](0005-security-secrets-and-cluster-isolation.md))

## Date

2026-11-26

## Context

All platform services (`ai-postgres-cluster`, `cnpg`, `litellm`, `temporal-*`, `phoenix`) run in the `ai-platform` namespace without east-west or egress restrictions, meaning any compromised workload could reach arbitrary cluster pods or external endpoints.

## Decision

- Add `terraform/modules/network-policies` deploying 9 `kubernetes_network_policy_v1` resources in `ai-platform`:
  - `default-deny-all`: denies all unpermitted ingress and egress across `ai-platform`.
  - `allow-dns-egress`: allows UDP/TCP `:53` to `kube-dns` in `kube-system`.
  - `postgres-least-privilege`: restricts `:5432` ingress to `litellm`, `temporal`, `phoenix`, `cloudnative-pg`, `batch` Jobs, and labeled `ai-factory/smoke-probe=true` pods.
  - `litellm-least-privilege`: allows Traefik (`kube-system`) + key-bootstrap Jobs on `:4000`, egresses only to Postgres `:5432` and host Ollama `:11434` (excluding cluster pod/service CIDRs).
  - `temporal-least-privilege`: allows Traefik on `:8080`, ServiceLB/Mac host on `:7233`, and intra-Temporal mesh ports, egressing only to Postgres `:5432` and Temporal peers.
  - `phoenix-least-privilege`: allows Traefik on `:6006`, egressing **only** to Postgres `:5432` (zero Ollama or internet egress).
  - `cnpg-operator-least-privilege`, `jobs-and-probes-egress`, and `smoke-probe-egress`.
- Verify policy count (`>= 9`) in `tests/smoke/cluster.sh` (`task doctor`).

## Consequences

- `task doctor` (`77/77` checks) proves that least-privilege `NetworkPolicy` enforcement keeps Traefik, CNPG, LiteLLM, Temporal, Phoenix, and Mac-to-Ollama connectivity working with zero manual workarounds.
