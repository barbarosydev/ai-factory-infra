#!/usr/bin/env bash
# Full platform health check: prerequisites, cluster & pods, PostgreSQL, Ollama,
# LiteLLM completions & virtual key scope, Temporal gRPC & sample workflow, and Web UIs.
#
# Usage: scripts/doctor.sh [--json]      (task doctor)
# Exit code: 0 when no check failed, 1 otherwise. WARN never fails.
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd jq kubectl

for arg in "$@"; do
  case "$arg" in
    --json) JSON_OUTPUT=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

run_suite() {
  local script="$1" out status check detail
  out="$("$script" --json 2>/dev/null || true)"
  if [[ -z "$out" ]] || ! jq -e '.checks' <<<"$out" >/dev/null 2>&1; then
    check_fail "$(basename "$script" .sh)" "suite did not return valid JSON: run $script"
    return
  fi
  while IFS=$'\t' read -r status check detail; do
    case "$status" in
      PASS) check_pass "$check" "$detail" ;;
      WARN) check_warn "$check" "$detail" ;;
      FAIL) check_fail "$check" "$detail" ;;
    esac
  done < <(jq -r '.checks[] | [.status, .check, .detail] | @tsv' <<<"$out")
}

# 1. Prerequisites (tools, versions, Docker resources, Ollama models, proxy, ports, pre-commit)
run_suite "$REPO_ROOT/scripts/doctor-prereqs.sh"

# 2. Cluster, project kubeconfig, node, Traefik :8080, pod-to-Ollama, user kubeconfig unchanged
run_suite "$REPO_ROOT/tests/smoke/cluster.sh"

# Check that all non-Job pods in ai-platform are Running and Ready
if [[ -f "$KUBECONFIG" ]] && [[ "$(cluster_state)" == "running" ]]; then
  not_ready="$(kc get pods -n ai-platform -o json 2>/dev/null | jq -r '
    [ .items[]
      | select(.status.phase != "Succeeded")
      | select(
          .status.phase != "Running"
          or ([.status.containerStatuses[]? | select(.ready == false)] | length) > 0
        )
      | .metadata.name
    ] | join(", ")
  ' || echo "query-failed")"
  total_pods="$(kc get pods -n ai-platform --no-headers 2>/dev/null | wc -l | tr -d ' ')"
  if [[ -z "$not_ready" && "${total_pods:-0}" -gt 0 ]]; then
    check_pass "ai-platform pods" "all $total_pods pod(s) Ready or Succeeded"
  else
    check_fail "ai-platform pods" "not ready: ${not_ready:-no pods in ai-platform}"
  fi
else
  check_fail "ai-platform pods" "cluster is not running: task up"
fi

# 3. PostgreSQL operator, cluster, databases and per-role login isolation
run_suite "$REPO_ROOT/tests/smoke/postgres.sh"

# 4. LiteLLM gateway, Admin UI, model completions and virtual key isolation
run_suite "$REPO_ROOT/tests/smoke/litellm.sh"

# 5. Temporal deployments, schema/namespace Jobs, host gRPC, Mac workflow and Web UI
run_suite "$REPO_ROOT/tests/smoke/temporal.sh"

finish_checks
