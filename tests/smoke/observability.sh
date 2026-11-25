#!/usr/bin/env bash
# Smoke test for Arize Phoenix observability: Deployment, UI, OTLP HTTP/protobuf
# ingestion, and REST API trace/span persistence readback (HTTP 200 alone is never enough).
#
# Usage: tests/smoke/observability.sh [--json]      (task smoke:observability)
# Exit code: 0 when no check failed.
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/../../scripts/lib/common.sh"
require_cmd kubectl curl jq python3

for arg in "$@"; do
  case "$arg" in
    --json) JSON_OUTPUT=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

NS="ai-platform"
PHOENIX_URL="http://phoenix.localhost:8080"

# --- Deployment & Environment Contract -------------------------------------

phx_avail="$(kc get deployment phoenix -n "$NS" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || true)"
if [[ "${phx_avail:-0}" -ge 1 ]]; then
  check_pass "phoenix deployment" "Ready in $NS"
else
  check_fail "phoenix deployment" "not Ready: task kube -- get pods -n $NS"
fi

retention_val="$(kc get deployment phoenix -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="PHOENIX_DEFAULT_RETENTION_POLICY_DAYS")].value}' 2>/dev/null || true)"
auth_val="$(kc get deployment phoenix -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="PHOENIX_ENABLE_AUTH")].value}' 2>/dev/null || true)"
if [[ "$retention_val" == "3" && "$auth_val" == "false" ]]; then
  check_pass "phoenix policy" "3-day retention policy & explicit loopback no-auth configured"
else
  check_fail "phoenix policy" "expected retention=3 and auth=false (got retention='${retention_val:-unset}', auth='${auth_val:-unset}')"
fi

# --- Web UI & Readiness via Traefik ----------------------------------------

ui_code="000"
ready_code="000"
for _ in {1..10}; do
  ui_code="$(curl -sS -o /dev/null -w '%{http_code}' --noproxy '*' --max-time 5 "$PHOENIX_URL/" 2>/dev/null || echo 000)"
  ready_code="$(curl -sS -o /dev/null -w '%{http_code}' --noproxy '*' --max-time 5 "$PHOENIX_URL/readyz" 2>/dev/null || echo 000)"
  if [[ "$ui_code" == "200" && "$ready_code" == "200" ]]; then
    break
  fi
  sleep 1
done
if [[ "$ui_code" == "200" && "$ready_code" == "200" ]]; then
  check_pass "phoenix UI & readyz" "$PHOENIX_URL answered HTTP 200"
else
  check_fail "phoenix UI & readyz" "UI=$ui_code readyz=$ready_code on $PHOENIX_URL"
fi

# --- OTLP HTTP/protobuf Ingestion + Exact Span Readback --------------------

smoke_span="ai-factory-smoke-$(date +%s)-$$"
if otlp_result="$(PHOENIX_URL="$PHOENIX_URL" SMOKE_SPAN="$smoke_span" python3 - 2>&1 <<'PY'
import os, secrets, struct, sys, time, urllib.request, json

base_url = os.environ["PHOENIX_URL"].rstrip("/")
span_name = os.environ["SMOKE_SPAN"]
project_name = "smoke-diagnostics"
parent_trace_hex = secrets.token_hex(16)
parent_span_hex = secrets.token_hex(8)
child_span_hex = secrets.token_hex(8)

def varint(n: int) -> bytes:
    out = bytearray()
    while n >= 0x80:
        out.append((n & 0x7F) | 0x80)
        n >>= 7
    out.append(n)
    return bytes(out)

def field_bytes(num: int, data: bytes) -> bytes:
    return varint((num << 3) | 2) + varint(len(data)) + data

def field_varint(num: int, val: int) -> bytes:
    return varint((num << 3) | 0) + varint(val)

def field_fixed64(num: int, val: int) -> bytes:
    return varint((num << 3) | 1) + struct.pack("<Q", val)

def kv_str(k: str, v: str) -> bytes:
    any_val = field_bytes(1, v.encode("utf-8"))
    return field_bytes(1, k.encode("utf-8")) + field_bytes(2, any_val)

now_ns = time.time_ns()
parent_span = (
    field_bytes(1, bytes.fromhex(parent_trace_hex))
    + field_bytes(2, bytes.fromhex(parent_span_hex))
    + field_bytes(5, span_name.encode("utf-8"))
    + field_varint(6, 1)
    + field_fixed64(7, now_ns)
    + field_fixed64(8, now_ns + 5_000_000)
    + field_bytes(9, kv_str("openinference.span.kind", "CHAIN"))
    + field_bytes(9, kv_str("smoke.diagnostic", "true"))
)
child_span = (
    field_bytes(1, bytes.fromhex(parent_trace_hex))
    + field_bytes(2, bytes.fromhex(child_span_hex))
    + field_bytes(4, bytes.fromhex(parent_span_hex))
    + field_bytes(5, (span_name + "-child").encode("utf-8"))
    + field_varint(6, 1)
    + field_fixed64(7, now_ns + 1_000_000)
    + field_fixed64(8, now_ns + 4_000_000)
    + field_bytes(9, kv_str("openinference.span.kind", "TOOL"))
)

resource = (
    field_bytes(1, kv_str("service.name", "ai-factory-infra-smoke"))
    + field_bytes(1, kv_str("openinference.project.name", project_name))
)
scope = field_bytes(1, b"tests.smoke.observability")
scope_spans = field_bytes(1, scope) + field_bytes(2, parent_span) + field_bytes(2, child_span)
resource_spans = field_bytes(1, resource) + field_bytes(2, scope_spans)
export_req = field_bytes(1, resource_spans)

opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
req = urllib.request.Request(
    f"{base_url}/v1/traces",
    data=export_req,
    headers={"Content-Type": "application/x-protobuf"},
    method="POST",
)
with opener.open(req, timeout=10) as resp:
    if resp.status not in (200, 202):
        print(f"ingest HTTP {resp.status}", file=sys.stderr)
        sys.exit(1)

deadline = time.time() + 15
while time.time() < deadline:
    try:
        qreq = urllib.request.Request(f"{base_url}/v1/projects/{project_name}/spans?limit=50")
        with opener.open(qreq, timeout=10) as qresp:
            payload = json.loads(qresp.read().decode("utf-8"))
        spans = payload.get("data") or []
        by_name = {s.get("name"): s for s in spans}
        p_obj = by_name.get(span_name)
        c_obj = by_name.get(span_name + "-child")
        if p_obj and c_obj:
            p_ctx = p_obj.get("context") or {}
            c_ctx = c_obj.get("context") or {}
            if (
                p_ctx.get("trace_id") == parent_trace_hex
                and c_ctx.get("trace_id") == parent_trace_hex
                and c_obj.get("parent_id") == p_ctx.get("span_id")
            ):
                print(f"trace={parent_trace_hex} project={project_name}")
                sys.exit(0)
    except Exception:
        pass
    time.sleep(0.5)

print("synthetic trace/span not returned by Phoenix query API within 15s", file=sys.stderr)
sys.exit(1)
PY
)"; then
  check_pass "phoenix OTLP & query" "ingested & queried parent+child span ($otlp_result)"
else
  check_fail "phoenix OTLP & query" "${otlp_result:-failed}"
fi

finish_checks
