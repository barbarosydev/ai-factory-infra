# ai-factory-infra

The instructions shared by every coding agent are in AGENTS.md.

@AGENTS.md

## Harness

Claude Code loads the path-specific conventions in `.claude/rules/` only when it reads or edits a matching file: `terraform.md` for `terraform/`, `scripts.md` for `scripts/`, `tests/` and `.claude/hooks/`.

Hooks in `.claude/hooks/` block cluster commands that bypass the project kubeconfig, block commits and pushes on main, block secrets in written files, format Terraform and sync `terraform-docs` after each edit, and report the branch when a session starts. `tests/hooks/run.sh` tests them alongside the Python helpers (`scripts/lib/temporal_grpc.py` and `scripts/lib/validate_tftpl.py`); change a hook only together with its tests.

Skills: `debug-stack`, `add-model-route`, `upgrade-version`, `rotate-secrets`, `ship-pr`. Agents: `terraform-reviewer`, `k8s-troubleshooter`, `version-security-auditor`, `platform-verifier`. Hooks, permissions and skills are described in `docs/harness.md`; the reasons are in `docs/adr/0006-agent-harness.md`.
