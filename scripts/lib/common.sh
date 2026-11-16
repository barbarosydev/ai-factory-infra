# shellcheck shell=bash
# Shared helpers for scripts/. Source it; do not run it.
#
# Checks report through check_pass, check_warn and check_fail. Each prints one
# fixed line (STATUS  name  detail), or collects JSON when JSON_OUTPUT=1.
# finish_checks prints the summary and returns 0 only when nothing failed.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_ROOT

# Pinned tools: mise.toml lists the exact version of every command line tool. Put
# them first on PATH here, so every script (and pre-commit, and any agent tool)
# runs the same versions without shell setup. Without mise, PATH stays as it is
# and task doctor:prereqs reports it.
if command -v mise >/dev/null 2>&1 && [[ -f "$REPO_ROOT/mise.toml" ]]; then
  eval "$(mise env -s bash -C "$REPO_ROOT" 2>/dev/null || true)" # no mise env: PATH unchanged
fi

# Every cluster command uses the project kubeconfig and nothing else.
# Your global ~/.kube/config (and any AKS context in it) is never read.
# USER_KUBECONFIG remembers where your own kubeconfig lives, only so the cluster
# scripts can prove they left it unchanged (they hash it, never print it).
USER_KUBECONFIG="${USER_KUBECONFIG:-${KUBECONFIG:-$HOME/.kube/config}}"
export USER_KUBECONFIG
CLUSTER_NAME="ai-factory"
KUBE_CONTEXT="k3d-${CLUSTER_NAME}"
# One live stack serves every git worktree of this repo. STACK_HOME is the checkout
# that holds the project kubeconfig and the Terraform state: the main worktree,
# unless STACK_HOME is set. Code (scripts, Terraform, k3d config) always comes
# from REPO_ROOT, so a worktree verifies its own branch against the one cluster.
if [[ -z "${STACK_HOME:-}" ]]; then
  STACK_HOME="$(git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')"
  [[ -n "$STACK_HOME" && -d "$STACK_HOME/terraform/environments/local" ]] || STACK_HOME="$REPO_ROOT"
fi
TF_STATE_FILE="$STACK_HOME/terraform/environments/local/terraform.tfstate"
KUBECONFIG="$STACK_HOME/.kube/config"
K3D_CONFIG="$REPO_ROOT/cluster/k3d-config.yaml"
OLLAMA_URL="${OLLAMA_URL:-http://127.0.0.1:11434}"
export STACK_HOME TF_STATE_FILE CLUSTER_NAME KUBE_CONTEXT KUBECONFIG K3D_CONFIG OLLAMA_URL

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
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd is not installed: mise install (see docs/prerequisites.md)"
  done
}

# --- Stack lock --------------------------------------------------------------
# Every worktree shares one live stack, so only one script may change it at a time.
# stack_lock takes the lock for the rest of the calling script and releases it on exit.
# The lock is a directory in STACK_HOME (mkdir is atomic); it records the holder's pid,
# checkout and command. A lock whose pid is gone is stale and is taken over. Scripts the
# holder calls (task up runs terraform.sh apply) see STACK_LOCK_HELD and do not lock again.
# Nothing waits: a busy stack fails at once and names the holder.

STACK_LOCK_DIR="${STACK_LOCK_DIR:-$STACK_HOME/.stack.lock}"
export STACK_LOCK_DIR

# stack_lock_holder: prints the holder recorded in the lock, or nothing.
stack_lock_holder() { cat "$STACK_LOCK_DIR/holder" 2>/dev/null || true; } # no lock: no holder

# stack_lock WHAT: take the lock for WHAT (for example "task apply"), or die naming the holder.
stack_lock() {
  local what="$1" pid
  [[ "${STACK_LOCK_HELD:-}" == "1" ]] && return 0
  if ! mkdir "$STACK_LOCK_DIR" 2>/dev/null; then
    pid="$(sed -n 's/^pid=//p' "$STACK_LOCK_DIR/holder" 2>/dev/null || true)" # no holder yet: checked below
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      die "the stack is busy: $(stack_lock_holder | tr '\n' ' ')- wait for it to finish, then run $what again"
    fi
    # A lock without a holder is being written right now, unless it is over a minute old.
    if [[ -z "$pid" && -z "$(find "$STACK_LOCK_DIR" -maxdepth 0 -mmin +1 2>/dev/null)" ]]; then
      die "the stack is busy (another run is taking the lock) - run $what again in a moment"
    fi
    warn "taking over a stale stack lock ($(stack_lock_holder | tr '\n' ' '))"
    rm -rf "$STACK_LOCK_DIR"
    mkdir "$STACK_LOCK_DIR" 2>/dev/null || die "another run took the stack lock just now; run $what again"
  fi
  printf 'pid=%s\ncheckout=%s\ncommand=%s\nsince=%s\n' "$$" "$REPO_ROOT" "$what" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$STACK_LOCK_DIR/holder"
  STACK_LOCK_HELD=1
  export STACK_LOCK_HELD
  trap stack_unlock EXIT
}

# stack_unlock: release the lock if this process holds it. Runs on exit after stack_lock.
stack_unlock() {
  local pid
  pid="$(sed -n 's/^pid=//p' "$STACK_LOCK_DIR/holder" 2>/dev/null || true)" # already gone: nothing to release
  [[ "$pid" == "$$" ]] && rm -rf "$STACK_LOCK_DIR"
  return 0
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
