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
7. Scripts follow the script contract in `.claude/rules/scripts.md`: bash with `set -euo pipefail`, readiness waits with a timeout, non-zero exit on any real failure, shellcheck clean.

## Conventions by path

Conventions for `terraform/` live in `.claude/rules/terraform.md`; conventions for `scripts/`, `tests/` and hooks live in `.claude/rules/scripts.md`.
Agents that do not load those files automatically must read the matching one before editing there.

## Workflow

1. One branch and one pull request per task; never commit on main. Work may happen in a git worktree.
2. Before every commit run `git status -sb`: the IDE has switched this checkout to another branch mid-task before. The branch-guard hook blocks commits on main, but not a wrong feature branch.
3. `task ci` must pass (pre-commit runs it on the staged changes anyway).
4. Record a fact a later session would need (a version found, a Mac quirk) in the docs or an ADR, not only in the conversation.
5. Every worktree runs its own branch's code against the one live stack. The stack's kubeconfig and Terraform state live in the main checkout (see `STACK_HOME` in `scripts/lib/common.sh`). Only one agent should run `task up` or `task apply` at a time; `task ci`, `task plan` and `task doctor` are safe from any worktree.

## Definition of done

Work in a loop: edit, run the checks, fix failures, repeat until green.

- `task ci` passes.
- If anything under `terraform/`, `cluster/`, `scripts/` or `tests/` changed: `task apply`, then a second `task plan` shows no changes, and `task doctor` is fully green (including the `tfstate secrets` check).
- Docs or an ADR are updated when behaviour, a pin, a port or a command changed.
- Stop at an open pull request. Never merge your own PR.

## Troubleshooting on this Mac

Check `docs/runbook.md`, section "Troubleshooting on this Mac", before debugging from scratch. Design reasons live in `docs/adr/`. Two facts apply to every task: completion probes need `max_tokens: 128` (`gemma4` models spend small budgets on thinking tokens), and do not add models above about 10 GB while the cluster runs.

## Docs

Diagrams in docs are Mermaid (```mermaid blocks), so GitHub renders them. No ASCII art or image files for diagrams.
