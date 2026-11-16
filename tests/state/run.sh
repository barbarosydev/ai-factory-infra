#!/usr/bin/env bash
# Tests for scripts/state-check.sh against fake state fixtures in tests/fixtures/.
# Usage: tests/state/run.sh      (task ci runs it through scripts/ci.sh)
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/../../scripts/lib/common.sh"
require_cmd jq
CHECK="$REPO_ROOT/scripts/state-check.sh"
FIX="$REPO_ROOT/tests/fixtures"
failed=0

# expect NAME EXIT_CODE OUTPUT_REGEX STATE_FILE
expect() {
  local name="$1" want="$2" re="$3" file="$4" got=0 out
  out="$(NO_COLOR=1 "$CHECK" "$file" 2>&1)" || got=$?
  if [[ "$got" == "$want" ]] && grep -Eq "$re" <<<"$out" && ! grep -q 'not-a-real-value' <<<"$out"; then
    printf '%sPASS%s  %-16s %s\n' "$C_GREEN" "$C_RESET" "state-check" "$name"
  else
    printf '%sFAIL%s  %-16s %s (exit %s, want %s)\n' "$C_RED" "$C_RESET" "state-check" "$name" "$got" "$want"
    failed=1
  fi
}

expect "clean state passes" 0 '^PASS .*0 secret-shaped' "$FIX/state-clean.json"
expect "missing state warns" 0 '^WARN .*no state yet' "$FIX/does-not-exist.json"
expect "leak fails, names only" 1 'FAIL.*3 secret-shaped.*auth_token.*db data.*random_password' "$FIX/state-leaked.json"

exit "$failed"
