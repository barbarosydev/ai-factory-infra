#!/usr/bin/env bash
# Bring the stack up: Ollama, the prerequisites check, then the cluster.
# Usage: scripts/up.sh      (task up)
# Safe to repeat: a running stack is left as it is.
# Phase 3 adds terraform apply after the cluster; phase 6 adds the full doctor.
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

"$REPO_ROOT/scripts/ollama.sh" start

info "checking prerequisites"
"$REPO_ROOT/scripts/doctor-prereqs.sh" >/dev/null || {
  "$REPO_ROOT/scripts/doctor-prereqs.sh" | grep '^FAIL' || true
  die "prerequisites failed: run task doctor:prereqs for the full report"
}

"$REPO_ROOT/scripts/cluster-setup.sh"

info "up: cluster $CLUSTER_NAME and Ollama are running (task status)"
