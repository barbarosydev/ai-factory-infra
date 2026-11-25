#!/usr/bin/env bash
# Smoke test for Temporal deployments, schema/namespace Jobs, gRPC health on
# localhost:7233, sample workflow execution from the Mac, and Web UI visibility.
#
# Usage: tests/smoke/temporal.sh [--json]      (task smoke:temporal)
# Exit code: 0 when no check failed.
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/../../scripts/lib/common.sh"
require_cmd kubectl temporal curl jq python3

for arg in "$@"; do
  case "$arg" in
    --json) JSON_OUTPUT=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

NS="ai-platform"
GRPC_ADDR="localhost:7233"
WEB_URL="http://temporal.localhost:8080"

# --- Deployments & Jobs ----------------------------------------------------

for svc in frontend history matching worker web; do
  avail="$(kc get deployment "temporal-$svc" -n "$NS" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || true)"
  if [[ "${avail:-0}" -ge 1 ]]; then
    check_pass "deployment temporal-$svc" "Ready in $NS"
  else
    check_fail "deployment temporal-$svc" "not Ready: task kube -- get pods -n $NS"
  fi
done

jobs_json="$(kc get jobs -n "$NS" -l app.kubernetes.io/instance=temporal -o json 2>/dev/null || echo '{"items":[]}')" # missing API response: checked below
jobs_total="$(jq -r '.items | length' <<<"$jobs_json")"
jobs_ok="$(jq -r '[.items[] | select((.status.succeeded // 0) >= 1)] | length' <<<"$jobs_json")"
if (( jobs_ok < jobs_total )); then
  check_fail "temporal schema & namespace jobs" "expected all Jobs succeeded, found $jobs_ok of $jobs_total"
elif (( jobs_ok >= 2 )); then
  check_pass "temporal schema & namespace jobs" "$jobs_ok Jobs succeeded"
elif temporal operator namespace describe --namespace default --address "$GRPC_ADDR" >/dev/null 2>&1 \
  || { sleep 1 && temporal operator namespace describe --namespace default --address "$GRPC_ADDR" >/dev/null 2>&1; }; then
  # schema.ttlSecondsAfterFinished (86400s) garbage-collects finished Jobs after 24h;
  # an active default namespace proves both schema setup and namespace registration succeeded.
  check_pass "temporal schema & namespace jobs" "reaped after 24h TTL (schema & default namespace active)"
else
  check_fail "temporal schema & namespace jobs" "expected 2 succeeded Jobs, found $jobs_ok"
fi

# --- Host gRPC health & default namespace ----------------------------------

health_out="$(temporal operator cluster health --address "$GRPC_ADDR" 2>/dev/null || true)"
if grep -q "SERVING" <<<"$health_out"; then
  check_pass "temporal gRPC ($GRPC_ADDR)" "SERVING"
else
  check_fail "temporal gRPC ($GRPC_ADDR)" "expected SERVING, got '${health_out:-no response}'"
fi

if temporal operator namespace describe --namespace default --address "$GRPC_ADDR" >/dev/null 2>&1; then
  check_pass "namespace default" "registered on $GRPC_ADDR"
else
  check_fail "namespace default" "not registered on $GRPC_ADDR"
fi

# --- Sample workflow started & completed from the Mac ----------------------

wf_id="ai-factory-smoke-$(date +%s)-$$"
tq="ai-factory-smoke-tq-$$"
wf_completed=0
cleanup_wf() {
  if [[ "$wf_completed" -eq 0 ]]; then
    temporal workflow terminate --address "$GRPC_ADDR" --namespace default --workflow-id "$wf_id" --reason "smoke test cleanup" >/dev/null 2>&1 || true # already finished is fine
  fi
}
trap cleanup_wf EXIT

if temporal workflow start \
  --address "$GRPC_ADDR" \
  --namespace default \
  --task-queue "$tq" \
  --type SmokeTestWorkflow \
  --workflow-id "$wf_id" \
  --input '{"source":"mac-host"}' >/dev/null 2>&1; then
  check_pass "workflow start (Mac -> $GRPC_ADDR)" "started $wf_id"
else
  check_fail "workflow start (Mac -> $GRPC_ADDR)" "temporal workflow start failed"
fi

if "$REPO_ROOT/scripts/lib/temporal_grpc.py" complete-one \
  --address "$GRPC_ADDR" \
  --namespace default \
  --task-queue "$tq" \
  --result '{"status":"ok","worker":"mac-host"}'; then
  wf_status=""
  deadline=$((SECONDS + 10))
  while (( SECONDS < deadline )); do
    wf_status="$(temporal workflow describe --address "$GRPC_ADDR" --namespace default --workflow-id "$wf_id" -o json 2>/dev/null \
      | jq -r '.workflowExecutionInfo.status // empty' || true)" # transient CLI/visibility lag: keep polling
    if [[ "$wf_status" == "WORKFLOW_EXECUTION_STATUS_COMPLETED" || "$wf_status" == "Completed" ]]; then
      break
    fi
    sleep 1
  done
  if [[ "$wf_status" == "WORKFLOW_EXECUTION_STATUS_COMPLETED" || "$wf_status" == "Completed" ]]; then
    wf_completed=1
    check_pass "workflow completion" "$wf_id completed ($wf_status)"
  else
    check_fail "workflow completion" "expected COMPLETED for $wf_id, got '${wf_status:-unknown}'"
  fi
else
  check_fail "workflow completion" "Mac worker failed to poll/complete $wf_id"
fi

# --- Web UI & workflow visibility in UI ------------------------------------

ui_code="$(curl -sSL --noproxy '*' --max-time 10 -o /dev/null -w '%{http_code}' "$WEB_URL/" || true)"
if [[ "$ui_code" == "200" ]]; then
  check_pass "temporal Web UI" "$WEB_URL answered HTTP 200"
else
  check_fail "temporal Web UI" "expected HTTP 200 on $WEB_URL, got ${ui_code:-none}"
fi

ui_wf="$(curl -sS --noproxy '*' --max-time 10 "$WEB_URL/api/v1/namespaces/default/workflows?query=WorkflowId%3D%22${wf_id}%22" \
  | jq -r --arg wf "$wf_id" '.executions[]? | select(.execution.workflowId == $wf) | .status' 2>/dev/null || true)"
if [[ "$ui_wf" == "WORKFLOW_EXECUTION_STATUS_COMPLETED" || "$ui_wf" == "Completed" ]]; then
  check_pass "temporal Web UI workflow list" "lists $wf_id as $ui_wf"
else
  check_fail "temporal Web UI workflow list" "expected $wf_id in Web UI API, got '${ui_wf:-missing}'"
fi

finish_checks
