#!/usr/bin/env bash
# Trial of the Claude Code Bash sandbox with the settings in tests/sandbox/settings.json.
# Starts headless Claude Code sessions (claude -p) and checks two things:
#   1. a script cannot read the global kubeconfig, the project kubeconfig or the
#      Terraform state, although it can read ordinary files;
#   2. task commands still work, because they are excluded from the sandbox.
# Not part of task ci: it needs a logged-in claude CLI, a running stack and a few
# cents of model use. Run it before copying the "sandbox" block into
# .claude/settings.json, and again after a Claude Code upgrade.
# Usage: tests/sandbox/run.sh
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/../../scripts/lib/common.sh"
require_cmd claude jq

SETTINGS="$REPO_ROOT/tests/sandbox/settings.json"

# ask SETTINGS_JSON COMMAND: run one Bash command in a headless session, print its reply.
ask() {
  (cd "$REPO_ROOT" && claude -p "Run exactly this one Bash command and reply with only its raw output: $2" \
    --settings "$1" --permission-mode dontAsk --allowedTools "Bash" --model haiku \
    --max-turns 3 --output-format json --no-session-persistence 2>&1) | jq -r '.result // empty' 2>/dev/null || true # empty reply is handled by the caller
}

probe="bash $REPO_ROOT/tests/sandbox/probe.sh"
plain="$(ask '{}' "$probe")"
if [[ -z "$plain" || "$plain" == *"authenticate"* ]]; then
  check_warn "claude cli" "no answer from claude -p (not logged in?): run claude in a terminal and log in, then repeat"
  finish_checks
  exit $?
fi
if grep -q 'READ_OK global-kubeconfig' <<<"$plain"; then
  check_pass "without sandbox" "a script can read the global kubeconfig (the gap the sandbox closes)"
else
  check_warn "without sandbox" "the probe could not read the global kubeconfig even without the sandbox"
fi

boxed="$(ask "$SETTINGS" "$probe")"
for f in global-kubeconfig project-kubeconfig state; do
  if grep -q "READ_BLOCKED $f" <<<"$boxed"; then
    check_pass "sandbox: $f" "blocked for scripts"
  else
    check_fail "sandbox: $f" "a script could still read it"
  fi
done
if grep -q 'READ_OK readme' <<<"$boxed"; then
  check_pass "sandbox: readme" "ordinary files stay readable"
else
  check_fail "sandbox: readme" "the probe did not run or could not read an ordinary file"
fi

doctor="$(ask "$SETTINGS" "task doctor -- --only cluster")"
if grep -q ' 0 failed' <<<"$doctor"; then
  check_pass "sandbox: task doctor" "excluded task commands still reach Docker and the cluster"
else
  check_fail "sandbox: task doctor" "task doctor -- --only cluster did not pass under the sandbox settings"
fi
finish_checks
