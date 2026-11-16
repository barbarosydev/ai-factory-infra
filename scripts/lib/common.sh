# shellcheck shell=bash
# Shared helpers for scripts/. Source it; do not run it.
#
# Checks report through check_pass, check_warn and check_fail. Each prints one
# fixed line (STATUS  name  detail), or collects JSON when JSON_OUTPUT=1.
# finish_checks prints the summary and returns 0 only when nothing failed.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_ROOT

# Every cluster command uses the project kubeconfig and nothing else.
# Your global ~/.kube/config (and any AKS context in it) is never read.
# USER_KUBECONFIG remembers where your own kubeconfig lives, only so the cluster
# scripts can prove they left it unchanged (they hash it, never print it).
USER_KUBECONFIG="${USER_KUBECONFIG:-${KUBECONFIG:-$HOME/.kube/config}}"
export USER_KUBECONFIG
CLUSTER_NAME="ai-factory"
KUBE_CONTEXT="k3d-${CLUSTER_NAME}"
KUBECONFIG="$REPO_ROOT/.kube/config"
K3D_CONFIG="$REPO_ROOT/cluster/k3d-config.yaml"
OLLAMA_URL="${OLLAMA_URL:-http://127.0.0.1:11434}"
export CLUSTER_NAME KUBE_CONTEXT KUBECONFIG K3D_CONFIG OLLAMA_URL

JSON_OUTPUT="${JSON_OUTPUT:-0}"
CHECKS_PASSED=0
CHECKS_WARNED=0
CHECKS_FAILED=0
CHECK_RESULTS_JSON="[]"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m' C_RED=$'\033[31m' C_RESET=$'\033[0m'
else
  C_GREEN="" C_YELLOW="" C_RED="" C_RESET=""
fi

_record() {
  local status="$1" name="$2" detail="$3" color="$4"
  if [[ "$JSON_OUTPUT" == "1" ]]; then
    CHECK_RESULTS_JSON="$(jq -c --arg s "$status" --arg n "$name" --arg d "$detail" \
      '. + [{status: $s, check: $n, detail: $d}]' <<<"$CHECK_RESULTS_JSON")"
  else
    printf '%s%-4s%s  %-22s %s\n' "$color" "$status" "$C_RESET" "$name" "$detail"
  fi
}

check_pass() { CHECKS_PASSED=$((CHECKS_PASSED + 1)); _record PASS "$1" "$2" "$C_GREEN"; }
check_warn() { CHECKS_WARNED=$((CHECKS_WARNED + 1)); _record WARN "$1" "$2" "$C_YELLOW"; }
check_fail() { CHECKS_FAILED=$((CHECKS_FAILED + 1)); _record FAIL "$1" "$2" "$C_RED"; }

finish_checks() {
  if [[ "$JSON_OUTPUT" == "1" ]]; then
    jq -n --argjson checks "$CHECK_RESULTS_JSON" \
      --argjson p "$CHECKS_PASSED" --argjson w "$CHECKS_WARNED" --argjson f "$CHECKS_FAILED" \
      '{passed: $p, warned: $w, failed: $f, ok: ($f == 0), checks: $checks}'
  else
    printf '\n%d passed, %d warned, %d failed\n' "$CHECKS_PASSED" "$CHECKS_WARNED" "$CHECKS_FAILED"
  fi
  [[ "$CHECKS_FAILED" -eq 0 ]]
}

# version_ge A B: true when version A >= version B (dotted numbers).
version_ge() {
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]
}

# first_version TEXT: the first dotted version number found in TEXT.
first_version() {
  grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?' <<<"$1" | head -n1
}

# --- Logging ---------------------------------------------------------------

info() { printf '==> %s\n' "$*" >&2; }
warn() { printf '%sWARN%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die() { printf '%sFAIL%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

# require_cmd CMD...: fail with an install hint when a command is missing.
require_cmd() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd is not installed: brew bundle --no-upgrade"
  done
}

# --- Cluster helpers -------------------------------------------------------

# kc ARGS...: kubectl pinned to the project kubeconfig and context.
kc() { kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" "$@"; }

# Pinned images for short-lived probe and smoke-test pods.
# busybox has no Terraform twin, so it is pinned here.
PROBE_IMAGE="busybox:1.37.0@sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec"
export PROBE_IMAGE

# Probes that need psql or LiteLLM's Python reuse the exact image (tag@digest) the
# cluster already runs, so terraform/environments/local/variables.tf is the only pin.
# Each prints the image, or returns 1 when the workload is missing.
postgres_probe_image() {
  local img
  img="$(kc get cluster.postgresql.cnpg.io/ai-postgres-cluster -n ai-platform \
    -o jsonpath='{.spec.imageName}' 2>/dev/null)" || return 1
  [[ -n "$img" ]] || return 1
  printf '%s\n' "$img"
}

litellm_probe_image() {
  local img
  img="$(kc get deployment litellm -n ai-platform \
    -o jsonpath='{.spec.template.spec.containers[?(@.name=="litellm")].image}' 2>/dev/null)" || return 1
  [[ -n "$img" ]] || return 1
  printf '%s\n' "$img"
}

# probe_pod NAME SCRIPT [TIMEOUT]: run SCRIPT with sh in a throwaway pod in
# namespace default, wait for it to finish (default 240 s), print its log and
# return 0 only when it succeeded. The pod is always removed.
probe_pod() {
  local pod="$1-$$" script="$2" timeout="${3:-240}" phase="" deadline
  kc run "$pod" -n default --restart=Never --image="$PROBE_IMAGE" \
    --command -- sh -c "$script" >/dev/null || return 1
  deadline=$((SECONDS + timeout))
  until [[ "$phase" == "Succeeded" || "$phase" == "Failed" ]]; do
    if (( SECONDS >= deadline )); then
      echo "probe pod $pod did not finish within ${timeout}s"
      break
    fi
    sleep 2
    phase="$(kc get pod "$pod" -n default -o jsonpath='{.status.phase}' 2>/dev/null || true)" # transient API errors: keep polling
  done
  kc logs "$pod" -n default 2>&1 || true # logs are diagnostics
  kc delete pod "$pod" -n default --ignore-not-found --wait=false >/dev/null 2>&1 || true # best-effort cleanup
  [[ "$phase" == "Succeeded" ]]
}

# cluster_state: prints absent, stopped or running for the k3d cluster.
cluster_state() {
  local counts
  counts="$(k3d cluster list -o json 2>/dev/null \
    | jq -r --arg n "$CLUSTER_NAME" '.[] | select(.name == $n) | "\(.serversRunning) \(.serversCount)"')"
  if [[ -z "$counts" ]]; then
    echo absent
  elif [[ "${counts% *}" -gt 0 && "${counts% *}" == "${counts#* }" ]]; then
    echo running
  else
    echo stopped
  fi
}

# user_kubeconfig_fingerprint: one hash over your own kubeconfig file(s), or
# "absent". Used before and after k3d runs; the contents are never printed.
user_kubeconfig_fingerprint() {
  local path out="" IFS=":"
  for path in $USER_KUBECONFIG; do
    if [[ -f "$path" ]]; then
      out+="$(shasum -a 256 "$path" | cut -d' ' -f1);"
    else
      out+="absent;"
    fi
  done
  printf '%s\n' "$out"
}

# ollama_answering: true when the Ollama API answers on OLLAMA_URL.
ollama_answering() { curl -fsS --noproxy '*' --max-time 3 "$OLLAMA_URL/api/version" >/dev/null 2>&1; }

# wait_until TIMEOUT_SECONDS WHAT CMD...: run CMD every 2 seconds until it
# succeeds. On timeout, fail and name WHAT. Waits on a condition, never blindly.
wait_until() {
  local timeout="$1" what="$2" deadline
  shift 2
  deadline=$((SECONDS + timeout))
  until "$@" >/dev/null 2>&1; do
    (( SECONDS < deadline )) || die "timed out after ${timeout}s waiting for $what"
    sleep 2
  done
}
