#!/usr/bin/env bash
# shellcheck disable=SC2016  # test commands stay unexpanded on purpose
# Tests for the Claude Code hooks in .claude/hooks/. Each case feeds the hook the
# same JSON that Claude Code sends and checks the exit code: 2 = blocked, 0 = allowed.
# Usage: tests/hooks/run.sh      (task ci runs it through scripts/lint.sh)
# Needs: python3, jq, git. Changes nothing outside a temporary directory.
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/../../scripts/lib/common.sh"
require_cmd jq git python3
HOOKS="$REPO_ROOT/.claude/hooks"
failed=0

# expect HOOK EXIT_CODE PROJECT_DIR COMMAND
expect() {
  local hook="$1" want="$2" dir="$3" cmd="$4" got=0
  jq -cn --arg c "$cmd" '{tool_input: {command: $c}}' \
    | CLAUDE_PROJECT_DIR="$dir" "$HOOKS/$hook" >/dev/null 2>&1 || got=$?
  if [[ "$got" == "$want" ]]; then
    printf '%sPASS%s  %-16s %s\n' "$C_GREEN" "$C_RESET" "$hook" "$cmd"
  else
    printf '%sFAIL%s  %-16s %s (exit %s, want %s)\n' "$C_RED" "$C_RESET" "$hook" "$cmd" "$got" "$want"
    failed=1
  fi
}

# --- kube-guard.py: project kubeconfig only, no state or secret reads ----------
k=kube-guard.py
expect $k 0 "$REPO_ROOT" 'task kube -- get pods -A'
expect $k 0 "$REPO_ROOT" 'kubectl --kubeconfig .kube/config get pods'
expect $k 0 "$REPO_ROOT" 'git status && terraform -chdir=terraform/environments/local plan'
expect $k 0 "$REPO_ROOT" 'echo "$(date)"'
expect $k 2 "$REPO_ROOT" 'kubectl get pods'
expect $k 2 "$REPO_ROOT" 'echo hi && kubectl get ns'
expect $k 2 "$REPO_ROOT" 'kubectl --kubeconfig ~/.kube/config get ns'
expect $k 2 "$REPO_ROOT" 'kubectl --kubeconfig .kube/config --context aks-prod get ns'
expect $k 2 "$REPO_ROOT" 'helm list -A'
expect $k 2 "$REPO_ROOT" 'kubectx'
expect $k 2 "$REPO_ROOT" 'kubectl --kubeconfig .kube/config config use-context other'
expect $k 2 "$REPO_ROOT" 'KUBE_CONFIG_PATH=~/.kube/config terraform plan'
expect $k 2 "$REPO_ROOT" 'terraform -chdir=terraform/environments/local state list'
expect $k 2 "$REPO_ROOT" 'task kube -- get secret db -o yaml'
expect $k 2 "$REPO_ROOT" 'task kube -- get -n ai-platform secret db -o yaml'
expect $k 2 "$REPO_ROOT" 'task kube -- get secret/db --template={{.data}}'
expect $k 2 "$REPO_ROOT" 'cat terraform/environments/local/terraform.tfstate'
expect $k 2 "$REPO_ROOT" 'python3 -c "open(\"terraform/environments/local/terraform.tfstate\")"'
expect $k 2 "$REPO_ROOT" 'grep token .env'
expect $k 0 "$REPO_ROOT" 'cat .env.example'
expect $k 0 "$REPO_ROOT" 'temporal operator cluster health --address localhost:7233'
expect $k 2 "$REPO_ROOT" 'temporal server start-dev'
expect $k 2 "$REPO_ROOT" 'temporal workflow list --address prod.tmprl.cloud:7233'
expect $k 2 "$REPO_ROOT" 'TEMPORAL_ADDRESS=prod.tmprl.cloud:7233 temporal workflow list'
# Nested commands
expect $k 2 "$REPO_ROOT" 'bash -c "kubectl get pods"'
expect $k 2 "$REPO_ROOT" 'eval kubectl get ns'
expect $k 2 "$REPO_ROOT" 'echo $(kubectl get ns)'
expect $k 2 "$REPO_ROOT" 'echo `cat .kube/config`'

# --- branch-guard.sh: no commit or push on main ---------------------------------
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git -C "$tmp" init -q -b main
git -C "$tmp" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m init
b=branch-guard.sh
expect $b 2 "$tmp" 'git commit -m "change"'
expect $b 2 "$tmp" 'git push'
expect $b 0 "$tmp" 'git status -sb'
expect $b 0 "$tmp" 'git switch -c feature'
git -C "$tmp" switch -q -c feature
expect $b 0 "$tmp" 'git commit -m "change"'
expect $b 0 "$tmp" 'git push -u origin feature'
expect $b 2 "$tmp" 'git push origin main'
expect $b 2 "$tmp" 'git push origin HEAD:main'

# A worktree session: the project directory is on main, the command runs in a
# worktree on its own branch (and the reverse). The hook follows the command's cwd.
# expect_cwd EXIT_CODE PROJECT_DIR CWD COMMAND
expect_cwd() {
  local want="$1" dir="$2" cwd="$3" cmd="$4" got=0
  jq -cn --arg c "$cmd" --arg d "$cwd" '{cwd: $d, tool_input: {command: $c}}' \
    | CLAUDE_PROJECT_DIR="$dir" "$HOOKS/$b" >/dev/null 2>&1 || got=$?
  if [[ "$got" == "$want" ]]; then
    printf '%sPASS%s  %-16s %s (cwd %s)\n' "$C_GREEN" "$C_RESET" "$b" "$cmd" "$(basename "$cwd")"
  else
    printf '%sFAIL%s  %-16s %s (cwd %s, exit %s, want %s)\n' "$C_RED" "$C_RESET" "$b" "$cmd" "$(basename "$cwd")" "$got" "$want"
    failed=1
  fi
}
git -C "$tmp" switch -q main
git -C "$tmp" worktree add -q "$tmp/wt-feature" -b wt-feature
expect_cwd 0 "$tmp" "$tmp/wt-feature" 'git commit -m "change"'
expect_cwd 0 "$tmp" "$tmp/wt-feature" 'git push -u origin wt-feature'
expect_cwd 2 "$tmp" "$tmp/wt-feature" 'git push origin main'
expect_cwd 2 "$tmp/wt-feature" "$tmp" 'git commit -m "change"'
expect_cwd 2 "$tmp" "$tmp/does-not-exist" 'git commit -m "change"'

# --- secret-guard.sh: no key or token written into a file -----------------------
# The fake token is assembled at run time so this file itself passes gitleaks.
if command -v gitleaks >/dev/null 2>&1; then
  fake="ghp_$(openssl rand -hex 18)"
  for case in "2|token = \"$fake\"" "0|replicas = 1"; do
    want="${case%%|*}" content="${case#*|}" got=0
    jq -cn --arg c "$content" '{tool_input: {file_path: "x.tf", content: $c}}' \
      | "$HOOKS/secret-guard.sh" >/dev/null 2>&1 || got=$?
    if [[ "$got" == "$want" ]]; then
      printf '%sPASS%s  %-16s %s\n' "$C_GREEN" "$C_RESET" secret-guard.sh "write: ${content/$fake/ghp_<random>}"
    else
      printf '%sFAIL%s  %-16s write (exit %s, want %s)\n' "$C_RED" "$C_RESET" secret-guard.sh "$got" "$want"
      failed=1
    fi
  done
fi

# --- Python helpers: temporal_grpc.py & validate_tftpl.py ----------------------
if python3 -B - "$REPO_ROOT" <<'PY'
import pathlib, sys
repo = pathlib.Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts" / "lib"))
import temporal_grpc as tg
import validate_tftpl as vt

# 1. Varint round-trip across single-byte and multi-byte boundaries
for val in [0, 1, 127, 128, 300, 16384, 2**32 - 1]:
    enc = tg.encode_varint(val)
    dec, pos = tg.decode_varint(enc, 0)
    assert dec == val and pos == len(enc), f"varint mismatch for {val}"

# 2. gRPC frame pack/unpack and PollWorkflowTaskQueueResponse token extraction
fake_token = b"temporal-task-token-12345"
poll_resp = tg.field_bytes(1, fake_token) + tg.field_varint(4, 42)
frame = tg.pack_grpc_frame(poll_resp)
unpacked = tg.unpack_grpc_frame(frame)
assert tg.extract_task_token(unpacked) == fake_token

# 3. RespondWorkflowTaskCompletedRequest builder & gRPC trailer status parser
comp_req = tg.build_complete_workflow_task_request("default", fake_token, "worker-1", '{"ok":true}')
assert fake_token in comp_req and b'{"ok":true}' in comp_req
status, msg = tg.parse_grpc_status("HTTP/2 200\r\ngrpc-status: 3\r\ngrpc-message: Context timeout is not set.\r\n")
assert status == 3 and "Context timeout" in msg

# 4. Template validator detects missing variables and passes current repo
assert vt.validate_all() == 0
assert vt.extract_tftpl_variables("host: ${ingress_host}\nport: ${grpc_port}") == {"ingress_host", "grpc_port"}
PY
then
  printf '%sPASS%s  %-16s %s\n' "$C_GREEN" "$C_RESET" "python-helpers" "temporal_grpc.py & validate_tftpl.py unit tests"
else
  printf '%sFAIL%s  %-16s %s\n' "$C_RED" "$C_RESET" "python-helpers" "temporal_grpc.py & validate_tftpl.py unit tests"
  failed=1
fi

exit "$failed"
