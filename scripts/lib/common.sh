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
CLUSTER_NAME="ai-factory"
KUBE_CONTEXT="k3d-${CLUSTER_NAME}"
KUBECONFIG="$REPO_ROOT/.kube/config"
export CLUSTER_NAME KUBE_CONTEXT KUBECONFIG

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
