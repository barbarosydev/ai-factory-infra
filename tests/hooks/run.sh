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

exit "$failed"
