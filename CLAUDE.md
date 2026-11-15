# ai-factory-infra

Local K3d Cluster + Terraform + Helm for LiteLLM and Temporal. No external API keys are allowed for the local sandbox phase.

## Architecture

- k3d cluster `ai-factory` (one k3s server) in Docker Desktop. Port 8080 serves web pages through the built-in Traefik ingress (`litellm.localhost:8080`, `temporal.localhost:8080`); port 7233 exposes Temporal to workers on the Mac.
- Terraform (`terraform/environments/local`, modules in `terraform/modules/`) installs everything inside the cluster in namespace `ai-platform`: CloudNativePG with one PostgreSQL server (databases `temporal`, `temporal_visibility`, `litellm`), LiteLLM, Temporal, and the `ollama` Service.
- Ollama runs natively on the Mac for the GPU. LiteLLM reaches it only through the `ollama` Service. Model routes: pm-agent on gemma4:12b, dev-agent and sec-agent on gemma4:e4b.
- The full plan and every decision: the master plan doc, mirrored in `docs/decisions/`.

## Commands

Use `task` for everything; `task --list` shows all tasks. Logic lives in `scripts/`, never in the Taskfile.

| Command | Use |
| --- | --- |
| `task doctor:prereqs` | Check the Mac before anything else |
| `task lint` | fmt, validate, tflint, shellcheck, JSON and YAML |
| `task ci` | lint plus gitleaks; must pass before every commit |
| `task kube -- <kubectl args>` | kubectl against the project cluster only |

Later phases add `task up`, `down`, `status`, `doctor`, `plan`, `apply` and `clean`.

## Hard rules

1. Every cluster command uses the project kubeconfig `.kube/config`, which holds only the `k3d-ai-factory` context. The global kubeconfig holds real AKS contexts: never use it, never switch contexts, never run kubectx or kubens. Use `task kube -- ...`.
2. All changes go through Terraform. No `kubectl apply`, `kubectl edit` or `helm install` by hand.
3. Use task commands to start, stop and verify. Run `task doctor` after every change (`task doctor:prereqs` until phase 6 lands the full doctor).
4. Never read or print Terraform state, tfvars, `.env`, the kubeconfig, or Kubernetes Secret values. Refer to secrets by name.
5. No secret in any file. Passwords are generated in the cluster or passed as write-only values. See `docs/secrets.md`.
6. Pin every version exactly (tools, charts, images, providers). Bump with the upgrade-version skill.
7. Scripts are bash with `set -euo pipefail`, source `scripts/lib/common.sh`, wait for readiness with a timeout instead of sleeping, and exit non-zero on any real failure. shellcheck must pass.

## Terraform conventions

- Helm provider 3.x and Kubernetes provider 3.x syntax: `set` and `set_sensitive` are lists of objects, and `kubernetes {}` inside the helm provider is an attribute (`kubernetes = { ... }`). Older tutorials use the 2.x block syntax and fail to validate. Use the Terraform MCP server for current docs.
- Each module has `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` and `values.yaml.tftpl` for its Helm values.
- Providers read `config_path = ".kube/config"` and `config_context = "k3d-ai-factory"`, never the default kubeconfig.

## Docs

Diagrams in docs are Mermaid (```mermaid blocks), so GitHub renders them. No ASCII art or image files for diagrams.

## Harness

Hooks in `.claude/hooks/` block cluster commands that bypass the project kubeconfig, block secrets in written files, and format Terraform after each edit. Skills: debug-stack, add-model-route, upgrade-version. Agents: terraform-reviewer, k8s-troubleshooter. `docs/harness.md` explains each piece.
