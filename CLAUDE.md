# ai-factory-infra

Local K3d Cluster + Terraform + Helm for LiteLLM and Temporal. No external API keys are allowed for the local sandbox phase.

## Architecture

- k3d cluster `ai-factory` (one k3s server, `cluster/k3d-config.yaml`) in Docker Desktop. `scripts/cluster-setup.sh` creates or resumes it and writes `.kube/config`; k3d never touches the global kubeconfig. Pods reach Ollama on the Mac at `host.k3d.internal:11434`. Port 8080 serves web pages through the built-in Traefik ingress (`litellm.localhost:8080`, `temporal.localhost:8080`); port 7233 exposes Temporal to workers on the Mac.
- Terraform (`terraform/environments/local`, modules in `terraform/modules/`) installs everything inside the cluster in namespace `ai-platform`: CloudNativePG with one PostgreSQL server (databases `temporal`, `temporal_visibility`, `litellm`), LiteLLM, Temporal, and the `ollama` Service.
- Ollama runs natively on the Mac for the GPU. LiteLLM reaches it only through the `ollama` Service. Model routes: pm-agent on gemma4:12b, dev-agent and sec-agent on gemma4:e4b.
- The full plan and every decision: the master plan doc, mirrored in `docs/decisions/`.

## Commands

Use `task` for everything; `task --list` shows all tasks. Logic lives in `scripts/`, never in the Taskfile.

| Command | Use |
| --- | --- |
| `task up` | Start Ollama, check prerequisites, create or resume the cluster |
| `task down` | Stop the cluster and unload Ollama models; data is kept |
| `task status` | Cluster, pods, loaded models and URLs |
| `task access` | UIs, secret names, API curl examples, and `-- --copy <target>` to clipboard |
| `task plan` / `task apply` | Terraform plan or apply for `terraform/environments/local` |
| `task smoke:cluster` | Cluster smoke test; `-- --lifecycle` also runs down and up |
| `task smoke:postgres` | PostgreSQL cluster, databases and per-role login isolation check |
| `task smoke:litellm` | LiteLLM gateway, Admin UI, model completions and virtual key scope check |
| `task smoke:temporal` | Temporal deployments, schema/namespace Jobs, gRPC health, Mac sample workflow and Web UI check |
| `task doctor:prereqs` | Check the Mac before anything else |
| `task lint` | fmt, validate, tflint, shellcheck, JSON and YAML |
| `task ci` | lint, hook tests and gitleaks; must pass before every commit |
| `task kube -- <kubectl args>` | kubectl against the project cluster only |

Also `task restart`, `stop:cluster`, `stop:ollama` and `clean` (deletes the cluster and its data). Later phases add `task doctor`, `plan`, `apply` and `clean:all`.

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
- Write-only Secrets: `kubernetes_secret_v1` in provider 3.5 uses `data_wo` and `data_wo_revision` (not `data_wo_version`), paired with `ephemeral "random_password"`, so secret values stay `null` in `terraform.tfstate`.
- Lockfile platforms: whenever providers change, run `terraform -chdir=terraform/environments/local providers lock -platform=darwin_arm64 -platform=linux_amd64 -platform=linux_arm64` so Linux CI and macOS stay in sync (`task lint` checks this).
- Each module has `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` and (when deploying a Helm chart) `values.yaml.tftpl`. Variables set `nullable = false` and `validation {}` blocks; Helm releases set `cleanup_on_fail = true` and `max_history = 5`; Kubernetes resources carry `app.kubernetes.io/part-of = "ai-factory"` and `app.kubernetes.io/managed-by = "terraform"` labels; `README.md` tables are generated with `terraform-docs` and checked by `task lint`.
- Providers read `config_path = ".kube/config"` and `config_context = "k3d-ai-factory"`, never the default kubeconfig.

## Workflow

1. One branch and one pull request per phase or task; never commit on main.
2. Before every commit run `git status -sb`: the IDE has switched this checkout to another branch mid-task before. The branch-guard hook blocks commits on main, but not a wrong feature branch.
3. `task ci` must pass (pre-commit runs it on the staged changes anyway).
4. Record a fact a later session would need (a version found, a Mac quirk) in the docs or the master plan, not only in the conversation.

## Known behaviour on this Mac

Found in phases 0 to 2. Check these before debugging from scratch:

- **Resume is slow on purpose.** After `task up` resumes a stopped cluster, pods cannot resolve `host.k3d.internal` for about 90 s. `cluster-setup.sh` waits for it; a fresh create takes about 50 s.
- **Ollama keeps the proxy it started with.** If it started while a proxy was set, `ollama pull` fails with `proxyconnect ... refused`. Fix: `task stop:ollama`, then `task up`. `task doctor:prereqs` warns.
- **A Docker Desktop sign-in can block images.** A work organization's registry rules refused `curlimages/curl` (`image access restricted`). Signing out lifts them; `task doctor:prereqs` warns while signed in. Probe pods use the official `busybox` image.
- **Docker Desktop's "system" proxy and the macOS PAC proxy are harmless.** In-cluster image pulls work through them.
- **Model sizes.** `gemma4:e4b` is 9.5 GB on disk (larger than its name suggests) and `gemma4:12b` 7.6 GB. Do not add models above about 10 GB while the cluster runs.
- **`gemma4` models use thinking tokens by default.** With `max_tokens: 16`, `gemma4:12b` and `gemma4:e4b` spend all 16 tokens in `thinking` and return an empty `content`. Completion probes should pass `max_tokens: 128` (or check `reasoning_content` / disable thinking).
- **Temporal chart `1.8.0` SQL setup and host gRPC.** Because CloudNativePG creates `temporal` and `temporal_visibility` owned by the non-superuser `temporal` role with strict `pg_hba` isolation, both SQL datastores in `terraform/modules/temporal/values.yaml.tftpl` must set `createDatabase: false` so `temporal-sql-tool` skips connecting to the admin `postgres` DB. `server.frontend.service.type: LoadBalancer` exposes `temporal-frontend:7233` directly to `localhost:7233` on the Mac via k3s ServiceLB (`127.0.0.1:7233:7233` in `cluster/k3d-config.yaml`). Raw HTTP/2 gRPC calls to `localhost:7233` require a `grpc-timeout` header (e.g. `grpc-timeout: 15S`).

## Docs

Diagrams in docs are Mermaid (```mermaid blocks), so GitHub renders them. No ASCII art or image files for diagrams.

## Harness

Hooks in `.claude/hooks/` block cluster commands that bypass the project kubeconfig, block commits and pushes on main, block secrets in written files, format Terraform after each edit, and report the branch when a session starts. `tests/hooks/run.sh` tests them; change a hook only together with its tests. Skills: debug-stack, add-model-route, upgrade-version. Agents: terraform-reviewer, k8s-troubleshooter, version-security-auditor. `docs/harness.md` explains each piece.
