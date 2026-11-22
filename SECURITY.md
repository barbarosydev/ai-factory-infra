# Security Policy

## Scope and Posture

`ai-factory-infra` provisions a local-only Kubernetes (`k3d`) platform for the AI Software Factory on macOS.

- **Zero External API Keys**: Only local Ollama models (`gemma4:12b`, `gemma4:e4b`) are used.
- **Zero Secrets in Git or State**: All database passwords and LiteLLM keys use Terraform ephemeral resources (`ephemeral "random_password"`) and write-only Kubernetes Secret attributes (`data_wo` + `data_wo_revision`). See [docs/secrets.md](docs/secrets.md) and [ADR 0005](docs/adr/0005-security-secrets-and-cluster-isolation.md).
- **Cluster Isolation**: Every command targets the project-local `.kube/config` (`k3d-ai-factory` context) and never touches `~/.kube/config`.

## Automated Security Gates

Every commit and Pull Request is gated by `task ci` (`scripts/ci.sh`):

1. **Conftest (OPA Rego) Policies** (`policy/`): Enforces write-only secrets, SHA-pinned container images (`@sha256:`), loopback-only k3d port bindings (`127.0.0.1`), read-only GitHub Actions tokens with commit-SHA-pinned actions, and Claude Code deny rules/hooks.
2. **Terraform State Secret Scan** (`task state:check` / `scripts/state-check.sh`): Verifies `terraform.tfstate` holds zero secret values.
3. **Secret Scanning** (`gitleaks`): Scans staged changes in `pre-commit` and full git history in CI.

## Reporting a Vulnerability

Please report security issues privately via [GitHub Security Advisories](https://github.com/barbarosydev/ai-factory-infra/security/advisories/new) rather than opening a public issue.
