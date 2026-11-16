#!/usr/bin/env bash
# Phase 5 smoke test for Temporal deployments, schema/namespace Jobs, gRPC health on
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

jobs_ok="$(kc get jobs -n "$NS" -l app.kubernetes.io/instance=temporal -o json 2>/dev/null \
  | jq -r '[.items[] | select((.status.succeeded // 0) >= 1)] | length' || echo 0)"
if [[ "${jobs_ok:-0}" -ge 2 ]]; then
  check_pass "temporal schema & namespace jobs" "$jobs_ok Jobs succeeded"
else
  check_fail "temporal schema & namespace jobs" "expected 2 succeeded Jobs, found ${jobs_ok:-0}"
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
    temporal workflow terminate --address "$GRPC_ADDR" --namespace default --workflow-id "$wf_id" --reason "smoke test cleanup" >/dev/null 2>&1 || true
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

if python3 - "$GRPC_ADDR" "$tq" <<'PY'
import subprocess, sys, tempfile

addr, tq = sys.argv[1], sys.argv[2]

def varint(n):
    out = bytearray()
    while n > 0x7F:
        out.append((n & 0x7F) | 0x80)
        n >>= 7
    out.append(n)
    return bytes(out)

def read_varint(buf, pos):
    val, shift = 0, 0
    while True:
        b = buf[pos]
        pos += 1
        val |= (b & 0x7F) << shift
        if not (b & 0x80):
            return val, pos
        shift += 7

def field_bytes(num, data):
    if isinstance(data, str):
        data = data.encode()
    return varint((num << 3) | 2) + varint(len(data)) + data

def field_varint(num, val):
    return varint((num << 3) | 0) + varint(val)

def grpc_call(method, payload):
    frame = b"\x00" + len(payload).to_bytes(4, "big") + payload
    url = f"http://{addr}/temporal.api.workflowservice.v1.WorkflowService/{method}"
    with tempfile.NamedTemporaryFile() as tf, tempfile.NamedTemporaryFile() as hf:
        tf.write(frame)
        tf.flush()
        proc = subprocess.run(
            [
                "curl", "-sS", "--noproxy", "*", "--http2-prior-knowledge",
                "--max-time", "20",
                "-D", hf.name,
                "-H", "Content-Type: application/grpc",
                "-H", "TE: trailers",
                "-H", "grpc-timeout: 15S",
                "-H", "Expect:",
                "--data-binary", f"@{tf.name}",
                url,
            ],
            capture_output=True,
            check=True,
        )
        headers = hf.read().decode(errors="replace")
    resp = proc.stdout
    if len(resp) < 5:
        raise RuntimeError(f"empty gRPC frame from {method}: headers={headers}")
    msg_len = int.from_bytes(resp[1:5], "big")
    return resp[5 : 5 + msg_len]

# 1. PollWorkflowTaskQueueRequest (namespace=1, task_queue=2{name=1,kind=2}, identity=3)
tq_msg = field_bytes(1, tq) + field_varint(2, 1)
poll_req = field_bytes(1, "default") + field_bytes(2, tq_msg) + field_bytes(3, "mac-smoke-worker")
poll_resp = grpc_call("PollWorkflowTaskQueue", poll_req)

pos = 0
task_token = b""
while pos < len(poll_resp):
    tag, pos = read_varint(poll_resp, pos)
    fnum, wtype = tag >> 3, tag & 7
    if wtype == 0:
        _, pos = read_varint(poll_resp, pos)
    elif wtype == 1:
        pos += 8
    elif wtype == 2:
        ln, pos = read_varint(poll_resp, pos)
        val = poll_resp[pos : pos + ln]
        pos += ln
        if fnum == 1:
            task_token = val
            break
    elif wtype == 5:
        pos += 4

if not task_token:
    raise RuntimeError("no task_token returned by PollWorkflowTaskQueue")

# 2. RespondWorkflowTaskCompletedRequest with COMMAND_TYPE_COMPLETE_WORKFLOW_EXECUTION (4)
meta = field_bytes(1, "encoding") + field_bytes(2, "json/plain")
payload = field_bytes(1, meta) + field_bytes(2, '{"status":"ok","worker":"mac-host"}')
payloads = field_bytes(1, payload)
complete_attrs = field_bytes(1, payloads)
cmd = field_varint(1, 4) + field_bytes(4, complete_attrs)
comp_req = (
    field_bytes(1, task_token)
    + field_bytes(2, cmd)
    + field_bytes(3, "mac-smoke-worker")
    + field_bytes(9, "default")
)
grpc_call("RespondWorkflowTaskCompleted", comp_req)
PY
then
  wf_status="$(temporal workflow describe --address "$GRPC_ADDR" --namespace default --workflow-id "$wf_id" -o json 2>/dev/null \
    | jq -r '.workflowExecutionInfo.status // empty' || true)"
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
