#!/usr/bin/env bash
# Smoke test for the cluster. Prints one PASS/WARN/FAIL line per check.
#
# Usage: tests/smoke/cluster.sh [--lifecycle] [--json]      (task smoke:cluster -- [--lifecycle])
#   default      read-only checks against the running cluster
#   --lifecycle  also runs task down then task up and checks that the same
#                cluster came back (same node UID) and your kubeconfig is unchanged
# Exit code: 0 when no check failed.
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/../../scripts/lib/common.sh"
require_cmd docker k3d kubectl jq curl shasum

OLLAMA_FROM_POD="http://host.k3d.internal:11434/api/version"

lifecycle=0
for arg in "$@"; do
  case "$arg" in
    --lifecycle) lifecycle=1 ;;
    --json) JSON_OUTPUT=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

fingerprint_before="$(user_kubeconfig_fingerprint)"
node_uid() { kc get nodes -o jsonpath='{.items[0].metadata.uid}' 2>/dev/null; }

if (( lifecycle )); then
  uid_before="$(node_uid || true)"
  [[ -n "$uid_before" ]] || die "the cluster must be running before --lifecycle: run task up"
  if "$REPO_ROOT/scripts/down.sh" >&2 && [[ "$(cluster_state)" == "stopped" ]]; then
    check_pass "down" "cluster stopped, data kept"
  else
    check_fail "down" "cluster did not stop: task down"
  fi
  if UP_SKIP_DOCTOR=1 "$REPO_ROOT/scripts/up.sh" >&2; then
    uid_after="$(node_uid || true)"
    if [[ "$uid_after" == "$uid_before" ]]; then
      check_pass "up resumes" "same node ${uid_after:0:8}, same cluster"
    else
      check_fail "up resumes" "node UID changed (${uid_before:0:8} to ${uid_after:0:8}): a new cluster was created"
    fi
  else
    check_fail "up resumes" "task up failed"
  fi
fi

# --- Cluster ---------------------------------------------------------------

state="$(cluster_state)"
if [[ "$state" == "running" ]]; then
  check_pass "cluster" "$CLUSTER_NAME is running"
else
  check_fail "cluster" "$CLUSTER_NAME is $state: task up"
fi

contexts="$(kubectl --kubeconfig "$KUBECONFIG" config get-contexts -o name 2>/dev/null || true)"
if [[ "$contexts" == "$KUBE_CONTEXT" ]]; then
  check_pass "project kubeconfig" "only $KUBE_CONTEXT"
else
  check_fail "project kubeconfig" "expected only $KUBE_CONTEXT, found: ${contexts:-no file}"
fi

image="$(kc get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}' 2>/dev/null || true)"
ready="$(kc get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
if [[ "$ready" == "True" ]]; then
  check_pass "node" "Ready, $image"
else
  check_fail "node" "not Ready: task kube -- describe nodes"
fi

netpol_count="$(kc get networkpolicy -n ai-platform -o json 2>/dev/null | jq -r '.items | length' || echo 0)"
if [[ "${netpol_count:-0}" -ge 9 ]]; then
  check_pass "network policies" "${netpol_count} NetworkPolicies active in ai-platform (default-deny + least-privilege)"
else
  check_fail "network policies" "expected >= 9 NetworkPolicies in ai-platform, got ${netpol_count:-0}"
fi

code="$(curl -s --noproxy '*' --max-time 5 -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/ || true)"
if [[ "$code" == "404" ]]; then
  check_pass "ingress :8080" "Traefik answers on port 8080 (404 for an unknown host)"
else
  check_fail "ingress :8080" "got HTTP ${code:-none}: task kube -- -n kube-system get pods"
fi

# --- Pod to Ollama on the Mac ----------------------------------------------

if reply="$(probe_pod ollama-probe "wget -qO- -T 10 $OLLAMA_FROM_POD")" \
  && version="$(jq -er '.version' <<<"$reply" 2>/dev/null)"; then
  check_pass "pod to Ollama" "host.k3d.internal:11434 answered, Ollama $version"
else
  check_fail "pod to Ollama" "no answer from $OLLAMA_FROM_POD: ${reply//$'\n'/ }"
fi

# --- Your kubeconfig ---------------------------------------------------------

if [[ "$(user_kubeconfig_fingerprint)" == "$fingerprint_before" ]]; then
  check_pass "your kubeconfig" "unchanged (hash compared, never read into output)"
else
  check_fail "your kubeconfig" "changed during this test: check your context with kubectx"
fi

finish_checks
