#!/usr/bin/env bash
# Unit tests for the pure functions in scripts/lib/common.sh: version_ge, first_version,
# check_pass/warn/fail, finish_checks, wait_until and cluster_state (with a stub k3d).
# Usage: tests/lib/run.sh      (needs jq; touches nothing outside a temporary directory)
set -euo pipefail

export NO_COLOR=1
# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/../../scripts/lib/common.sh"
require_cmd jq
failed=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# check NAME WANT GOT
check() {
  if [[ "$3" == "$2" ]]; then
    printf '%sPASS%s  %-16s %s\n' "$C_GREEN" "$C_RESET" common.sh "$1"
  else
    printf '%sFAIL%s  %-16s %s (got %q, want %q)\n' "$C_RED" "$C_RESET" common.sh "$1" "$3" "$2"
    failed=1
  fi
}

# rc CMD...: run CMD in a subshell and print its exit status
rc() { local s=0; ( "$@" ) >/dev/null 2>&1 || s=$?; echo "$s"; }

# --- version_ge -------------------------------------------------------------
for c in "1.2.3 1.2.3 0" "1.2.4 1.2.3 0" "1.2.2 1.2.3 1" "2 1.9 0" "1.9 2 1" "1.10 1.9 0" \
  "1.9 1.10 1" "1.30.1 1.9.9 0" "1.2 1.2.0 1" "1.2.0 1.2 0" "10.0.0 9.99.99 0"; do
  read -r a b want <<<"$c"
  check "version_ge $a $b" "$want" "$(rc version_ge "$a" "$b")"
done

# --- first_version ----------------------------------------------------------
check "first_version tool output" "1.9.4" "$(first_version 'Terraform v1.9.4 on darwin_arm64')"
check "first_version two numbers" "5.3" "$(first_version 'k3d version v5.3, k3s v1.31.2')"
check "first_version three parts" "1.31.2" "$(first_version 'client: v1.31.2')"
check "first_version none" "" "$(first_version 'no version here')"

# --- check recording, text mode ----------------------------------------------
out="$( (check_pass alpha "all good"; check_warn beta "careful"; check_fail gamma "broken"; finish_checks) 2>&1 || true)"
check "text PASS line" "PASS  alpha                  all good" "$(sed -n 1p <<<"$out")"
check "text WARN line" "WARN  beta                   careful" "$(sed -n 2p <<<"$out")"
check "text FAIL line" "FAIL  gamma                  broken" "$(sed -n 3p <<<"$out")"
check "text summary" "1 passed, 1 warned, 1 failed" "$(tail -n1 <<<"$out")"
check "counters" "2 1 1" "$( (check_pass a b; check_pass c d; check_warn e f; check_fail g h; echo "$CHECKS_PASSED $CHECKS_WARNED $CHECKS_FAILED") | tail -n1)"
check "counters do not leak" "0 0 0" "$CHECKS_PASSED $CHECKS_WARNED $CHECKS_FAILED"

# --- finish_checks exit status -----------------------------------------------
check "finish: none" 0 "$(rc finish_checks)"
check "finish: pass only" 0 "$(s=0; (check_pass a b; finish_checks) >/dev/null || s=$?; echo "$s")"
check "finish: warnings only" 0 "$(s=0; (check_pass a b; check_warn c d; finish_checks) >/dev/null || s=$?; echo "$s")"
check "finish: a failure" 1 "$(s=0; (check_pass a b; check_warn c d; check_fail e f; finish_checks) >/dev/null || s=$?; echo "$s")"

# --- check recording, JSON mode ----------------------------------------------
json="$( (JSON_OUTPUT=1; check_pass alpha "all good"; check_warn beta 'quote " and \ back'; check_fail gamma "broken"; finish_checks) || true)"
check "json is one valid document" "true" "$(jq -e . >/dev/null 2>&1 <<<"$json" && echo true || echo false)"
check "json counts" "1 1 1 false" "$(jq -r '"\(.passed) \(.warned) \(.failed) \(.ok)"' <<<"$json")"
check "json statuses" "PASS WARN FAIL" "$(jq -r '[.checks[].status] | join(" ")' <<<"$json")"
check "json names" "alpha beta gamma" "$(jq -r '[.checks[].check] | join(" ")' <<<"$json")"
check "json escapes detail" 'quote " and \ back' "$(jq -r '.checks[1].detail' <<<"$json")"
okjson="$( (JSON_OUTPUT=1; check_pass a b; check_warn c d; finish_checks))"
check "json ok with warnings only" "true" "$(jq -r '.ok' <<<"$okjson")"
check "json mode has no text lines" "0" "$(grep -c '^PASS\|^WARN\|^FAIL' <<<"$json" || true)"
check "json exit status" 1 "$(s=0; (JSON_OUTPUT=1; check_fail a b; finish_checks) >/dev/null 2>&1 || s=$?; echo "$s")"

# --- wait_until ----------------------------------------------------------------
check "wait_until succeeds at once" 0 "$(rc wait_until 5 "nothing" true)"
check "wait_until times out" 1 "$(rc wait_until 0 "nothing" false)"
check "wait_until names what it waited for" "1" \
  "$( (wait_until 0 "the flux capacitor" false 2>&1 || true) | grep -c 'timed out after 0s waiting for the flux capacitor')"
check "wait_until passes arguments" 0 "$(rc wait_until 5 "args" test "a" = "a")"
check "wait_until hides command output" "" "$(wait_until 5 quiet echo noisy 2>&1)"

# --- cluster_state with a stub k3d -----------------------------------------------
mkdir -p "$tmp/bin"
cat >"$tmp/bin/k3d" <<'STUB'
#!/usr/bin/env bash
cat "$K3D_FIXTURE"
STUB
chmod +x "$tmp/bin/k3d"
state() { # state JSON: cluster_state against a fixture
  printf '%s\n' "$1" >"$tmp/fixture.json"
  ( PATH="$tmp/bin:$PATH" K3D_FIXTURE="$tmp/fixture.json" cluster_state )
}
check "cluster_state absent (empty list)" absent "$(state '[]')"
check "cluster_state absent (other cluster)" absent "$(state '[{"name":"other","serversRunning":1,"serversCount":1}]')"
check "cluster_state running" running "$(state '[{"name":"ai-factory","serversRunning":1,"serversCount":1}]')"
check "cluster_state stopped" stopped "$(state '[{"name":"ai-factory","serversRunning":0,"serversCount":1}]')"
check "cluster_state picks its own cluster" running \
  "$(state '[{"name":"other","serversRunning":0,"serversCount":1},{"name":"ai-factory","serversRunning":1,"serversCount":1}]')"

# --- stack_lock / stack_unlock -----------------------------------------------
lock_dir="$tmp/stack.lock"
check "stack_lock creates lock and releases on exit" "released" \
  "$( ( STACK_LOCK_DIR="$lock_dir"; stack_lock "test run"; [[ -f "$lock_dir/holder" ]] ) && [[ ! -d "$lock_dir" ]] && echo released || echo leaked )"

check "stack_lock allows nested calls in the same process" "ok" \
  "$( ( STACK_LOCK_DIR="$lock_dir"; stack_lock "outer"; stack_lock "inner"; echo ok ) )"

# Hold a live lock in a background subshell and verify a second caller fails naming the holder.
(
  STACK_LOCK_DIR="$lock_dir"
  stack_lock "task up"
  sleep 2
) &
holder_pid=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [[ -f "$lock_dir/holder" ]] && break
  sleep 0.1
done
busy_out="$( ( STACK_LOCK_DIR="$lock_dir"; stack_lock "task apply" ) 2>&1 || true )"
kill "$holder_pid" 2>/dev/null || true
wait "$holder_pid" 2>/dev/null || true
rm -rf "$lock_dir"
check "stack_lock fails when held by a live pid" "1" "$(grep -c 'the stack is busy: .*command=task up' <<<"$busy_out")"

# A lock whose pid is dead is stale and taken over.
mkdir -p "$lock_dir"
printf 'pid=999999\ncheckout=/tmp/old\ncommand=task up\nsince=2026-01-01T00:00:00Z\n' >"$lock_dir/holder"
stale_out="$( ( STACK_LOCK_DIR="$lock_dir"; stack_lock "task apply"; echo taken ) 2>&1 )"
check "stack_lock takes over stale lock" "1" "$(grep -c 'taking over a stale stack lock' <<<"$stale_out")"
check "stack_lock succeeds after stale takeover" "1" "$(grep -c '^taken$' <<<"$stale_out")"

# --- PROBE_IMAGE pin ----------------------------------------------------------
check "PROBE_IMAGE is pinned by version and sha256 digest" "1" \
  "$(grep -Ec '^[^:]+:[0-9]+\.[0-9]+\.[0-9]+@sha256:[0-9a-f]{64}$' <<<"$PROBE_IMAGE")"

# --- scripts/terraform.sh preserves local state in main checkout and worktrees -
if command -v terraform >/dev/null 2>&1; then
  tf_repo="$tmp/tf-repo"
  mkdir -p "$tf_repo/scripts/lib" "$tf_repo/terraform/environments/local" "$tf_repo/.kube"
  cp "$REPO_ROOT/scripts/terraform.sh" "$tf_repo/scripts/terraform.sh"
  cp "$REPO_ROOT/scripts/lib/common.sh" "$tf_repo/scripts/lib/common.sh"
  chmod +x "$tf_repo/scripts/terraform.sh"
  : >"$tf_repo/.kube/config"
  cat >"$tf_repo/terraform/environments/local/versions.tf" <<'EOF'
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
EOF
  cat >"$tf_repo/terraform/environments/local/main.tf" <<'EOF'
variable "kubeconfig_path" { type = string }
resource "terraform_data" "x" { input = "ok" }
EOF
  (
    # shellcheck disable=SC2046
    unset $(git rev-parse --local-env-vars)
    git -C "$tf_repo" init -q -b main
    git -C "$tf_repo" add -A
    git -C "$tf_repo" -c user.name=t -c user.email=t@example.invalid commit -q -m init
    git -C "$tf_repo" worktree add -q "$tmp/tf-wt" -b wt
  )
  tf_rc=0
  (
    # shellcheck disable=SC2046
    unset $(git rev-parse --local-env-vars)
    env -u STACK_HOME "$tf_repo/scripts/terraform.sh" apply >/dev/null 2>&1
    env -u STACK_HOME "$tf_repo/scripts/terraform.sh" plan -detailed-exitcode >/dev/null 2>&1
  ) || tf_rc=$?
  check "terraform.sh plan in main checkout preserves state (no-op)" "0" "$tf_rc"
  tf_rc=0
  (
    # shellcheck disable=SC2046
    unset $(git rev-parse --local-env-vars)
    env -u STACK_HOME "$tmp/tf-wt/scripts/terraform.sh" plan -detailed-exitcode >/dev/null 2>&1
  ) || tf_rc=$?
  check "terraform.sh plan in worktree preserves state (no-op)" "0" "$tf_rc"
  tf_rc=0
  (
    # shellcheck disable=SC2046
    unset $(git rev-parse --local-env-vars)
    env -u STACK_HOME "$tf_repo/scripts/terraform.sh" plan -detailed-exitcode >/dev/null 2>&1
  ) || tf_rc=$?
  check "terraform.sh plan back in main checkout preserves state (no-op)" "0" "$tf_rc"
fi

exit "$failed"
