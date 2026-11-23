# ai-factory-infra

Personal async multi-agent software factory: the local platform it runs on.

LiteLLM, Temporal and PostgreSQL in a k3d cluster on a Mac, with Ollama running natively for the GPU. Terraform and Helm install everything; `task` runs everything. No external API keys: only local models. See [docs/architecture.md](docs/architecture.md).

## What runs

| Part | Where | Reached at |
| --- | --- | --- |
| k3d cluster `ai-factory` (one k3s server) | Docker Desktop | project kubeconfig `.kube/config` only |
| PostgreSQL (CloudNativePG, databases `temporal`, `temporal_visibility`, `litellm`) | namespace `ai-platform` | inside the cluster |
| LiteLLM gateway and Admin UI | namespace `ai-platform` | `http://litellm.localhost:8080` |
| Temporal server and Web UI | namespace `ai-platform` | `http://temporal.localhost:8080`, gRPC `localhost:7233` |
| Ollama | natively on the Mac | from pods through the `ollama` Service |

Model routes: `pm-agent` on gemma4:12b, `dev-agent`, `test-agent` and `sec-agent` on gemma4:e4b. Every tool, chart, image, provider and GitHub Action is pinned exactly ([ADR 0002](docs/adr/0002-toolchain-versions-and-pinning.md)).

## Getting started

1. Set up the Mac: [docs/prerequisites.md](docs/prerequisites.md). The command line tools come from one file, [mise.toml](mise.toml):

```bash
brew bundle --no-upgrade
mise install
```

2. Check the Mac, and turn on the checks before each commit:

```bash
task doctor:prereqs
```

```bash
pre-commit install
```

3. Start the stack (runs `task doctor` automatically at the end), check status/access, and stop it again when done (data is kept):

```bash
task up
```

```bash
task doctor
task status
task access
```

```bash
task down
```

`task --list` shows every command; [docs/runbook.md](docs/runbook.md) says when to use each.

## Checks

`task ci` is the one check. pre-commit runs it on the staged changes and GitHub Actions runs it on every pull request and on `main`, so the two cannot drift apart. It runs:

- `task lint`: Terraform fmt, validate, tflint, terraform-docs and the module tests (`terraform test`, mock providers, no cluster); shellcheck; ruff; JSON and YAML syntax; the [Conftest policies](policy/README.md); actionlint; links and paths in the docs.
- The tests for the hooks, the state check, the script library and the Python helpers.
- gitleaks over the staged changes or the whole history.

Against the live stack, `task doctor` checks everything end to end (including that Terraform state holds no secret value), and `task smoke:*` checks one part in depth ([tests/smoke/README.md](tests/smoke/README.md)).

## Repo layout

| Path | What it holds |
| --- | --- |
| [AGENTS.md](AGENTS.md) | Instructions for every coding agent: architecture, commands, hard rules, workflow, definition of done. [CLAUDE.md](CLAUDE.md) imports it. |
| [mise.toml](mise.toml), [Brewfile](Brewfile) | Pinned command line tools; Homebrew installs only mise (and k9s). |
| [Taskfile.yml](Taskfile.yml) | Thin task runner: each task calls one script. |
| [cluster/](cluster/README.md) | The k3d cluster config. |
| [terraform/](terraform/environments/local/README.md) | One environment (`terraform/environments/local`) and the modules it calls, each with its own tests. |
| `scripts/` | All the logic behind `task`, with shared helpers in `scripts/lib/`. |
| `tests/` | `smoke/` (live stack), `hooks/`, `state/`, `lib/` and `python/` (run by `task ci`), `sandbox/` (optional Claude Code sandbox trial). |
| [policy/](policy/README.md) | Conftest rules that turn the hard rules into checks. |
| `.claude/` | The agent harness: permissions, hooks, path-scoped rules, skills and review roles ([docs/harness.md](docs/harness.md)). |
| `.github/` | The CI workflow and the pull request template. |
| [docs/](docs/) | Prerequisites, architecture, runbook, secrets, harness and the ADRs. |

## Working on it

One branch and one pull request per task; `task ci` must pass before every commit. If a change touches `terraform/`, `cluster/`, `scripts/` or `tests/`, also run `task apply`, a second `task plan` (no changes) and `task doctor` (fully green). All git worktrees share the one live stack; only one may run `task up` or `task apply` at a time. Details: [AGENTS.md](AGENTS.md).

## Not in scope yet

Deliberately left out for now, each with the reason in an ADR:

- Cloud model routes: local models only until API credit exists ([ADR 0004](docs/adr/0004-model-gateway-and-agent-routes.md)).
- Renovate and a live-stack job in GitHub Actions: versions are bumped with the `upgrade-version` skill, and the live stack is verified on the Mac ([ADR 0002](docs/adr/0002-toolchain-versions-and-pinning.md), [ADR 0007](docs/adr/0007-operations-contract-and-verification.md)).
- GitHub secret scanning, push protection and branch protection are not enabled for this repository; gitleaks and the branch-guard hook provide local checks ([ADR 0005](docs/adr/0005-security-secrets-and-cluster-isolation.md)).

## Docs

- [Prerequisites](docs/prerequisites.md)
- [Architecture](docs/architecture.md)
- [Runbook](docs/runbook.md)
- [Secrets](docs/secrets.md)
- [Agent harness](docs/harness.md)
- [Architecture decision records](docs/adr/README.md)
