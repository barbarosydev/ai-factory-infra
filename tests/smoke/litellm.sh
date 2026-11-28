#!/usr/bin/env bash
# Smoke test for the ollama Service, LiteLLM, Admin UI, completions and virtual key isolation.
# Prints one PASS/WARN/FAIL line per check; never reads or prints Secret values.
#
# Usage: tests/smoke/litellm.sh [--json] [--fast]      (task smoke:litellm)
#   --fast  verify Service, Deployment, Admin UI, and /v1/models virtual key scope without loading LLMs
# Exit code: 0 when no check failed.
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/../../scripts/lib/common.sh"
require_cmd kubectl jq curl

fast_mode=0
for arg in "$@"; do
  case "$arg" in
    --json) JSON_OUTPUT=1 ;;
    --fast) fast_mode=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

NS="ai-platform"
LITELLM_IMAGE="$(litellm_probe_image)" || LITELLM_IMAGE="" # empty: the route checks below fail

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
fast = os.environ.get("FAST_MODE") == "1"
base = "http://litellm:4000/v1/chat/completions"
models_url = "http://litellm:4000/v1/models"
for agent in ["pm-agent", "dev-agent", "test-agent", "sec-agent"]:
    key = os.environ["KEY_" + agent.upper().replace("-", "_")]
    if fast:
        req = urllib.request.Request(models_url, headers={"Authorization": "Bearer " + key})
        with urllib.request.urlopen(req, timeout=15) as resp:
            ids = [m.get("id") for m in json.loads(resp.read()).get("data", [])]
            if resp.status == 200 and agent in ids:
                print(f"OK:{agent}:models")
                continue
        print(f"FAIL:{agent}")
        sys.exit(1)

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
    if e.code in (400, 401, 403):
        print(f"DENIED:{e.code}")
    else:
        print(f"FAIL:unexpected-http-{e.code}")
        sys.exit(1)
'

overrides="$(jq -cn --arg pod "$pod" --arg img "$LITELLM_IMAGE" --arg py "$py_script" --arg fast "$fast_mode" '{
  metadata: {
    labels: {
      "ai-factory/smoke-probe": "true"
    }
  },
  spec: {
    containers: [{
      name: $pod,
      image: $img,
      imagePullPolicy: "IfNotPresent",
      command: ["python3", "-c", $py],
      env: [
        {name: "FAST_MODE",      value: $fast},
        {name: "KEY_PM_AGENT",   valueFrom: {secretKeyRef: {name: "litellm-pm-agent-key",   key: "api_key"}}},
        {name: "KEY_DEV_AGENT",  valueFrom: {secretKeyRef: {name: "litellm-dev-agent-key",  key: "api_key"}}},
        {name: "KEY_TEST_AGENT", valueFrom: {secretKeyRef: {name: "litellm-test-agent-key", key: "api_key"}}},
        {name: "KEY_SEC_AGENT",  valueFrom: {secretKeyRef: {name: "litellm-sec-agent-key",  key: "api_key"}}}
      ]
    }]
  }
}')"

if out="$(kc run "$pod" --rm -i --restart=Never -n "$NS" --image="$LITELLM_IMAGE" --overrides="$overrides" 2>/dev/null)"; then
  for agent in pm-agent dev-agent test-agent sec-agent; do
    if grep -q "OK:${agent}:" <<<"$out"; then
      if (( fast_mode )); then
        check_pass "route $agent" "HTTP 200 authorized on /v1/models (--fast)"
      else
        check_pass "route $agent" "HTTP 200 non-empty completion with scoped virtual key"
      fi
    else
      check_fail "route $agent" "completion or /v1/models check failed"
    fi
  done
  if grep -Eq "DENIED:(400|401|403)$" <<<"$out"; then
    code="${out##*DENIED:}"
    code="${code%%$'\n'*}"
    check_pass "virtual key scope" "pm-agent key rejected on dev-agent (HTTP $code)"
  else
    check_fail "virtual key scope" "pm-agent key was not cleanly rejected with 400/401/403 on dev-agent"
  fi
else
  check_fail "litellm completions" "smoke pod failed in $NS"
fi

finish_checks
