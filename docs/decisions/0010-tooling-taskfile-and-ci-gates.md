# ADR-0010: Open-Source Tooling, Thin Taskfile, and Pre-Commit CI Gates

## Context

A platform repository should be reproducible on a fresh clone with minimal commands and give identical lint/security results locally and in GitHub Actions.

## Decision

1. **Open-source first:** Standardize on open-source tools engineers already use (`k3d`, `k3s`, `Traefik`, `CloudNativePG`, `Temporal`, `LiteLLM`, `Ollama`, `Task`, `tflint`, `terraform-docs`, `shellcheck`, `pre-commit`, `gitleaks`), with two approved exceptions: Docker Desktop and Terraform (`1.17.2`).
2. **One-command bootstrap:** Ship a `Brewfile` (`brew bundle`) and `task doctor:prereqs` to verify every tool version and host setting.
3. **Thin Taskfile:** Keep `Taskfile.yml` declarative where each task delegates to one testable bash script in `scripts/` (`set -euo pipefail`, sourcing `scripts/lib/common.sh`).
4. **Unified CI gate:** Run `task ci` (`terraform fmt`, `validate`, multi-platform lockfile check, `tflint`, `terraform-docs --output-check`, `shellcheck`, 38 hook unit tests, and `gitleaks`) in both `pre-commit` (`--staged`) and GitHub Actions (`.github/workflows/ci.yml`).

## Why

- Keeping logic in `scripts/` instead of YAML makes every script directly lintable by `shellcheck` and testable in isolation.
- Calling the exact same `task ci` entry point in `pre-commit` and GitHub Actions eliminates local-vs-CI drift.

## Consequences

- Every commit is checked automatically before it is created, and `task doctor` verifies the live runtime stack end-to-end.
