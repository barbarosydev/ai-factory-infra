# shellcheck shell=bash
# Shared helpers for scripts/. Source it; do not run it.
#
# Checks report through check_pass, check_warn and check_fail. Each prints one
# fixed line (STATUS  name  detail), or collects JSON when JSON_OUTPUT=1.
# finish_checks prints the summary and returns 0 only when nothing failed.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_ROOT

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
