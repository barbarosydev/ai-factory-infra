#!/usr/bin/env bash
# Sandbox probe, run by tests/sandbox/run.sh through a headless Claude Code session.
# Stands in for "a script the agent wrote": tries to read files the harness denies.
# Reads one byte to /dev/null and prints only READ_OK or READ_BLOCKED per file.
set -uo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/../../scripts/lib/common.sh"

probe() {
  if head -c 1 "$1" >/dev/null 2>&1; then echo "READ_OK $2"; else echo "READ_BLOCKED $2"; fi
}
probe "$USER_KUBECONFIG" global-kubeconfig
probe "$KUBECONFIG" project-kubeconfig
probe "$TF_STATE_FILE" state
probe "$REPO_ROOT/README.md" readme
