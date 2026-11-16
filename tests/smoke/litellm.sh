#!/usr/bin/env bash
# Smoke test for the ollama Service, LiteLLM, Admin UI, completions and virtual key isolation.
# Prints one PASS/WARN/FAIL line per check; never reads or prints Secret values.
#
# Usage: tests/smoke/litellm.sh [--json]      (task smoke:litellm)
# Exit code: 0 when no check failed.
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/../../scripts/lib/common.sh"
require_cmd kubectl jq curl

for arg in "$@"; do
  case "$arg" in
    --json) JSON_OUTPUT=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

NS="ai-platform"
LITELLM_IMAGE="$LITELLM_PROBE_IMAGE"

# --- Service & Deployment --------------------------------------------------

ext_name="$(kc get svc ollama -n "$NS" -o jsonpath='{.spec.externalName}' 2>/dev/null || true)"
if [[ "$ext_name" == "host.k3d.internal" ]]; then
  check_pass "service ollama" "ExternalName -> $ext_name:11434"
else
  check_fail "service ollama" "expected host.k3d.internal, found '${ext_name:-missing}'"
fi

avail="$(kc get deployment litellm -n "$NS" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || true)"
if [[ "${avail:-0}" -ge 1 ]]; then
  check_pass "litellm deployment" "Ready in $NS"
else
  check_fail "litellm deployment" "not Ready: task kube -- get pods -n $NS"
fi

ui_code="$(curl -sSL --noproxy '*' --max-time 10 -o /dev/null -w '%{http_code}' http://litellm.localhost:8080/ui || true)"
if [[ "$ui_code" == "200" ]]; then
  check_pass "litellm admin UI" "http://litellm.localhost:8080/ui answered HTTP 200"
else
  check_fail "litellm admin UI" "expected HTTP 200 on http://litellm.localhost:8080/ui, got ${ui_code:-none}"
fi

# --- Completions & virtual key isolation (in-cluster pod, Secrets never printed) ---

pod="litellm-smoke-$$"
py_script='
import json, os, sys, time, urllib.error, urllib.request
base = "http://litellm:4000/v1/chat/completions"
for agent in ["pm-agent", "dev-agent", "sec-agent"]:
    key = os.environ["KEY_" + agent.upper().replace("-", "_")]
    body = json.dumps({
        "model": agent,
        "messages": [{"role": "user", "content": "Reply with OK."}],
        "temperature": 0,
        "max_tokens": 128,
    }).encode()
    ok = False
    for attempt in range(3):
        try:
            req = urllib.request.Request(base, data=body, headers={
                "Authorization": "Bearer " + key,
                "Content-Type": "application/json",
            }, method="POST")
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = json.loads(resp.read())
                msg = data["choices"][0]["message"]
                text = (msg.get("content") or msg.get("reasoning_content") or "").strip()
                if resp.status == 200 and len(text) > 0:
                    print(f"OK:{agent}:{len(text)}")
                    ok = True
                    break
        except Exception:
            time.sleep(2)
    if not ok:
        print(f"FAIL:{agent}")
        sys.exit(1)

req = urllib.request.Request(
    base,
    data=json.dumps({"model": "dev-agent", "messages": [{"role": "user", "content": "hi"}]}).encode(),
    headers={"Authorization": "Bearer " + os.environ["KEY_PM_AGENT"], "Content-Type": "application/json"},
    method="POST",
)
try:
    urllib.request.urlopen(req, timeout=15)
    print("FAIL:isolation")
    sys.exit(1)
except urllib.error.HTTPError as e:
    print(f"DENIED:{e.code}")
'

overrides="$(jq -cn --arg pod "$pod" --arg img "$LITELLM_IMAGE" --arg py "$py_script" '{
  spec: {
    containers: [{
      name: $pod,
      image: $img,
      imagePullPolicy: "IfNotPresent",
      command: ["python3", "-c", $py],
      env: [
        {name: "KEY_PM_AGENT",  valueFrom: {secretKeyRef: {name: "litellm-pm-agent-key",  key: "api_key"}}},
        {name: "KEY_DEV_AGENT", valueFrom: {secretKeyRef: {name: "litellm-dev-agent-key", key: "api_key"}}},
        {name: "KEY_SEC_AGENT", valueFrom: {secretKeyRef: {name: "litellm-sec-agent-key", key: "api_key"}}}
      ]
    }]
  }
}')"

if out="$(kc run "$pod" --rm -i --restart=Never -n "$NS" --image="$LITELLM_IMAGE" --overrides="$overrides" 2>/dev/null)"; then
  for agent in pm-agent dev-agent sec-agent; do
    if grep -q "OK:${agent}:" <<<"$out"; then
      check_pass "route $agent" "HTTP 200 non-empty completion with scoped virtual key"
    else
      check_fail "route $agent" "completion failed"
    fi
  done
  if grep -q "DENIED:" <<<"$out"; then
    code="${out##*DENIED:}"
    code="${code%%$'\n'*}"
    check_pass "virtual key scope" "pm-agent key rejected on dev-agent (HTTP $code)"
  else
    check_fail "virtual key scope" "pm-agent key was not rejected on dev-agent"
  fi
else
  check_fail "litellm completions" "smoke pod failed in $NS"
fi

finish_checks
