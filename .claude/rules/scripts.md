---
paths:
  - "scripts/**"
  - "tests/**"
  - ".claude/hooks/**"
---

# Script, test and hook conventions

Reasons: `docs/adr/0007-operations-contract-and-verification.md`.

- Bash with `set -euo pipefail`; source `scripts/lib/common.sh`.
- Safe to repeat: running a script again gives the same result.
- Wait for readiness with a timeout (`wait_until` in `scripts/lib/common.sh`), never a fixed sleep.
- Exit non-zero on any real failure. A WARN never fails. An `|| true` needs a short comment saying why absence is fine.
- Report through `check_pass`, `check_warn` and `check_fail`: fixed `PASS`, `WARN` and `FAIL` lines, or JSON with `--json`.
- shellcheck must pass (`task lint`).
- Logic lives in `scripts/`; the Taskfile only calls them.
- Never print state, the kubeconfig or Secret values: names and counts only.
- Use `STACK_HOME`, `KUBECONFIG` and `TF_STATE_FILE` from `scripts/lib/common.sh` for the live stack's paths, not paths built from `REPO_ROOT`.
- Change a hook only together with its tests in `tests/hooks/run.sh`; `scripts/lib/common.sh` has tests in `tests/lib/run.sh` and the Python helpers in `tests/python/` (stdlib `unittest`). ruff must pass.
- A test that calls git must first drop git's hook environment, as `tests/hooks/run.sh` does with `unset $(git rev-parse --local-env-vars)`.
