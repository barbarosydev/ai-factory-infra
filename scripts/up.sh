#!/usr/bin/env bash
# Bring the stack up: Ollama, the prerequisites check, the cluster, then Terraform.
# Usage: scripts/up.sh      (task up)
# Safe to repeat: a running stack is left as it is.
# Phase 6 adds the full doctor.
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

"$REPO_ROOT/scripts/ollama.sh" start

info "checking prerequisites"
# Show only WARN and FAIL lines; a warning (for example Ollama holding an old
# proxy, or a Docker sign-in) explains a failure later in the run.
prereqs_ok=1
report="$(NO_COLOR=1 "$REPO_ROOT/scripts/doctor-prereqs.sh")" || prereqs_ok=0
grep -E '^(WARN|FAIL)' <<<"$report" >&2 || true
(( prereqs_ok )) || die "prerequisites failed: run task doctor:prereqs for the full report"

"$REPO_ROOT/scripts/cluster-setup.sh"
"$REPO_ROOT/scripts/terraform.sh" apply

info "up: cluster $CLUSTER_NAME, Ollama and Terraform are up (task status)"
