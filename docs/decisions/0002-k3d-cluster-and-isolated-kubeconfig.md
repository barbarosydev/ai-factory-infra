# ADR-0002: k3d Cluster and Isolated Project Kubeconfig

## Context

The developer's global `~/.kube/config` contains production and staging AKS contexts. Any local platform command that reads or mutates the global kubeconfig risks touching a real cloud cluster.

## Decision

1. Run a single-server **k3d** (`5.9.0`) cluster named `ai-factory` pinned to `rancher/k3s:v1.37.2-k3s1` (by tag and digest in `cluster/k3d-config.yaml`), publishing host ports `127.0.0.1:8080` (Traefik HTTP ingress) and `127.0.0.1:7233` (Temporal frontend gRPC).
2. Store the cluster kubeconfig exclusively inside the repository at `.kube/config` (gitignored). All scripts (`scripts/lib/common.sh`), Terraform providers (`terraform/environments/local/providers.tf`), and `task kube` read only `.kube/config` with context `k3d-ai-factory`.

## Why

- k3s is CNCF-certified Kubernetes in one lightweight container (~1.3 GiB base footprint) that `k3d` starts and stops in seconds while keeping persistent volumes intact across `task down` and `task up`.
- Isolating `.kube/config` inside the repo guarantees that no script, Terraform run, or AI agent can ever reach the AKS contexts in `~/.kube/config`.

## Consequences

- Lifecycle scripts hash `$HOME/.kube/config` before and after `k3d` runs and fail if the hash ever changes.
- `.claude/hooks/kube-guard.py` blocks any `kubectl`, `helm`, `k9s`, `kubectx`, or `kubens` call that bypasses `.kube/config` or `k3d-ai-factory`.
