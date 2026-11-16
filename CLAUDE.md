# ai-factory-infra

Local K3d Cluster + Terraform + Helm for LiteLLM and Temporal. No external API keys are allowed in this local sandbox.

## Architecture

- k3d cluster `ai-factory` (one k3s server, `cluster/k3d-config.yaml`) in Docker Desktop. `scripts/cluster-setup.sh` creates or resumes it and writes `.kube/config`; k3d never touches the global kubeconfig. Pods reach Ollama on the Mac at `host.k3d.internal:11434`. Port 8080 serves web pages through the built-in Traefik ingress (`litellm.localhost:8080`, `temporal.localhost:8080`); port 7233 exposes Temporal to workers on the Mac.
- Terraform (`terraform/environments/local`, modules in `terraform/modules/`) installs everything inside the cluster in namespace `ai-platform`: CloudNativePG with one PostgreSQL server (databases `temporal`, `temporal_visibility`, `litellm`), LiteLLM, Temporal, and the `ollama` Service.
- Ollama runs natively on the Mac for the GPU. LiteLLM reaches it only through the `ollama` Service. Model routes: pm-agent on gemma4:12b, dev-agent and sec-agent on gemma4:e4b.
- Decisions and their reasons: `docs/adr/`.

## Commands

Use `task` for everything; `task --list` shows all tasks. Logic lives in `scripts/`, never in the Taskfile.

| Command | Use |
| --- | --- |
| `task up` | Start Ollama, check prerequisites, create or resume the cluster, apply Terraform, and run `task doctor` |
| `task down` | Stop the cluster and unload Ollama models; data is kept |
| `task doctor` | Full health check across prerequisites, cluster, Postgres, Ollama, LiteLLM, Temporal, Web UIs and the state secret check (`-- --json` for JSON, `-- --only <suites>` for a subset) |
| `task status` | Cluster, pods, container/pod memory use, loaded models and URLs |
| `task access` | UIs, secret names, API curl examples, and `-- --copy <target>` to clipboard |
| `task plan` / `task apply` | Terraform plan or apply for `terraform/environments/local` |
| `task smoke:cluster` | Cluster smoke test; `-- --lifecycle` also runs down and up |
| `task smoke:postgres` | PostgreSQL cluster, databases and per-role login isolation check |
| `task smoke:litellm` | LiteLLM gateway, Admin UI, model completions and virtual key scope check |
| `task smoke:temporal` | Temporal deployments, schema/namespace Jobs, gRPC health, Mac sample workflow and Web UI check |
| `task state:check` | Check Terraform state holds no secret values (prints a count only; also part of `task doctor`) |
| `task doctor:prereqs` | Check the Mac before anything else |
| `task lint` | fmt, validate, tflint, terraform-docs, shellcheck, JSON and YAML |
| `task ci` | lint, hook tests and gitleaks; must pass before every commit |
| `task kube -- <kubectl args>` | kubectl against the project cluster only |

Also `task restart`, `stop:cluster`, `stop:ollama`, `clean` (deletes the cluster and its data), and `clean:all` (also removes Terraform caches and, if confirmed, Ollama models).

## Hard rules

1. Every cluster command uses the project kubeconfig `.kube/config`, which holds only the `k3d-ai-factory` context. The global kubeconfig holds real AKS contexts: never use it, never switch contexts, never run kubectx or kubens. Use `task kube -- ...`.
2. All changes go through Terraform. No `kubectl apply`, `kubectl edit` or `helm install` by hand.
3. Use task commands to start, stop and verify. Run `task doctor` after every change.
4. Never read or print Terraform state, tfvars, `.env`, the kubeconfig, or Kubernetes Secret values. Refer to secrets by name.
5. No secret in any file. Passwords are generated in the cluster or passed as write-only values. See `docs/secrets.md`.
6. Pin every version exactly (tools, charts, images, providers). Bump with the upgrade-version skill.
7. Scripts are bash with `set -euo pipefail`, source `scripts/lib/common.sh`, wait for readiness with a timeout instead of sleeping, and exit non-zero on any real failure. shellcheck must pass.

## Terraform conventions

- Helm provider 3.x and Kubernetes provider 3.x syntax: `set` and `set_sensitive` are lists of objects, and `kubernetes {}` inside the helm provider is an attribute (`kubernetes = { ... }`). Older tutorials use the 2.x block syntax and fail to validate. Use the Terraform MCP server for current docs.
- Write-only Secrets: `kubernetes_secret_v1` in provider 3.5 uses `data_wo` and `data_wo_revision` (not `data_wo_version`), paired with `ephemeral "random_password"`, so secret values stay `null` in `terraform.tfstate`.
- Lockfile platforms: whenever providers change, run `terraform -chdir=terraform/environments/local providers lock -platform=darwin_arm64 -platform=linux_amd64 -platform=linux_arm64` so Linux CI and macOS stay in sync (`task lint` checks this).
- Each module has `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` and (when deploying a Helm chart) `values.yaml.tftpl`. Variables set `nullable = false` and `validation {}` blocks; Helm releases set `cleanup_on_fail = true` and `max_history = 5`; Kubernetes resources carry `app.kubernetes.io/part-of = "ai-factory"` and `app.kubernetes.io/managed-by = "terraform"` labels; `README.md` tables are generated with `terraform-docs` and checked by `task lint`.
- Providers read `config_path = ".kube/config"` and `config_context = "k3d-ai-factory"`, never the default kubeconfig.

## Workflow

1. One branch and one pull request per task; never commit on main.
2. Before every commit run `git status -sb`: the IDE has switched this checkout to another branch mid-task before. The branch-guard hook blocks commits on main, but not a wrong feature branch.
3. `task ci` must pass (pre-commit runs it on the staged changes anyway).
4. Record a fact a later session would need (a version found, a Mac quirk) in the docs or an ADR, not only in the conversation.

## Troubleshooting on this Mac

Check `docs/runbook.md`, section "Troubleshooting on this Mac", before debugging from scratch. Design reasons live in `docs/adr/`. Two facts apply to every task: completion probes need `max_tokens: 128` (`gemma4` models spend small budgets on thinking tokens), and do not add models above about 10 GB while the cluster runs.

## Docs

Diagrams in docs are Mermaid (```mermaid blocks), so GitHub renders them. No ASCII art or image files for diagrams.

## Harness

Hooks in `.claude/hooks/` block cluster commands that bypass the project kubeconfig, block commits and pushes on main, block secrets in written files, format Terraform and sync `terraform-docs` after each edit, and report the branch when a session starts. `tests/hooks/run.sh` tests them alongside the Python helpers (`scripts/lib/temporal_grpc.py` and `scripts/lib/validate_tftpl.py`); change a hook only together with its tests. Skills: `debug-stack`, `add-model-route`, `upgrade-version`, `rotate-secrets`, `ship-pr`. Agents: `terraform-reviewer`, `k8s-troubleshooter`, `version-security-auditor`, `platform-verifier`. `docs/harness.md` explains each piece.
