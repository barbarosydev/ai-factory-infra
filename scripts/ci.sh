#!/usr/bin/env bash
# The one check that pre-commit and GitHub Actions both run: lint, the hook tests and a secret scan.
# Usage: scripts/ci.sh [--staged]
#   --staged  scan only the staged changes (pre-commit uses this)
#   default   scan the whole git history (GitHub Actions and manual runs)
# Exit code: 0 when lint passes and no secret is found, 1 otherwise.
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
cd "$REPO_ROOT"

mode="history"
for arg in "$@"; do
  case "$arg" in
    --staged) mode="staged" ;;
    *) die "unknown argument: $arg" ;;
  esac
done

info "lint"
"$REPO_ROOT/scripts/lint.sh"

info "hook tests"
"$REPO_ROOT/tests/hooks/run.sh"

info "state check tests"
"$REPO_ROOT/tests/state/run.sh"

require_cmd gitleaks
# Git mode only: a directory scan would read gitignored files such as .kube/config.
# --redact keeps any finding out of logs, so a leak is not repeated in CI output.
if [[ "$mode" == "staged" ]]; then
  info "secret scan (staged changes)"
  gitleaks git --staged --redact --no-banner --exit-code 1 .
else
  info "secret scan (whole history)"
  gitleaks git --redact --no-banner --exit-code 1 .
fi
