#!/usr/bin/env bash
# Full platform health check: prerequisites, cluster & pods, PostgreSQL, Ollama,
# LiteLLM completions & virtual key scope, Temporal gRPC & sample workflow, and Web UIs.
#
# Usage:
#   scripts/doctor.sh [--json] [--only <suites>]      (task doctor)
#   where <suites> is a comma-separated list of: prereqs,cluster,postgres,litellm,temporal,state
# Exit code: 0 when no check failed, 1 otherwise. WARN never fails.
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd jq kubectl python3

only_filter=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      JSON_OUTPUT=1
      shift
      ;;
    --only)
      [[ $# -ge 2 ]] || die "usage: task doctor -- --only <prereqs|cluster|postgres|litellm|temporal|state>"
      only_filter="$2"
      shift 2
      ;;
    --only=*)
      only_filter="${1#--only=}"
      shift
      ;;
    *)
      echo "unknown argument: $1 (usage: scripts/doctor.sh [--json] [--only <suites>])" >&2
      exit 2
      ;;
  esac
done

should_run() {
  local suite="$1"
  [[ -z "$only_filter" ]] && return 0
  [[ ",${only_filter}," == *",${suite},"* ]]
}

if [[ -n "$only_filter" ]]; then
  for token in ${only_filter//,/ }; do
    case "$token" in
      prereqs | cluster | postgres | litellm | temporal | state) ;;
      *) die "unknown suite '$token' in --only (choose from: prereqs,cluster,postgres,litellm,temporal,state)" ;;
    esac
  done
fi

run_suite() {
  local script="$1" out status check detail
  out="$("$script" --json 2>/dev/null || true)" # exits 1 on FAIL; JSON checked next
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
if should_run prereqs; then
  run_suite "$REPO_ROOT/scripts/doctor-prereqs.sh"
fi

# 2. Cluster, project kubeconfig, node, Traefik :8080, pod-to-Ollama, ai-platform pods, user kubeconfig unchanged
if should_run cluster; then
  run_suite "$REPO_ROOT/tests/smoke/cluster.sh"

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
fi

# 3. PostgreSQL operator, cluster, databases and per-role login isolation
if should_run postgres; then
  run_suite "$REPO_ROOT/tests/smoke/postgres.sh"
fi

# 4. LiteLLM gateway, Admin UI, model completions and virtual key isolation
if should_run litellm; then
  run_suite "$REPO_ROOT/tests/smoke/litellm.sh"
fi

# 5. Temporal deployments, schema/namespace Jobs, host gRPC, Mac workflow and Web UI
if should_run temporal; then
  run_suite "$REPO_ROOT/tests/smoke/temporal.sh"
fi

# 6. Terraform state holds no secret values (prints counts and addresses, never values)
if should_run state; then
  run_suite "$REPO_ROOT/scripts/state-check.sh"
fi

finish_checks
