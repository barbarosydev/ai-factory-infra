#!/usr/bin/env bash
# SessionStart hook: tell Claude where the checkout stands when a session starts.
# For SessionStart, whatever this prints on stdout is added to Claude's context,
# so it starts from facts (branch, uncommitted files) instead of guessing.
# Read-only and fast: git only, no Docker or cluster calls.
# Reports the directory the session runs in (the hook input's cwd): in a git
# worktree that differs from the project directory and has its own branch.
# Tests: tests/hooks/run.sh
set -uo pipefail

dir=""
if command -v jq >/dev/null 2>&1 && [[ ! -t 0 ]]; then
  dir="$(jq -r '.cwd // empty' 2>/dev/null || true)" # no hook input: fall back below
fi
[[ -n "$dir" && -d "$dir" ]] || dir="${CLAUDE_PROJECT_DIR:-.}"
cd "$dir" 2>/dev/null || exit 0
branch="$(git branch --show-current 2>/dev/null)" || exit 0
changes="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"

echo "Checkout: branch ${branch:-detached HEAD}, ${changes} uncommitted file(s)."
if [[ "$branch" == "main" ]]; then
  echo "main is checked out: create a branch before changing files (branch-guard blocks commits on main)."
fi

# The kubeconfig and Terraform state live in the main worktree (the stack home).
stack_home="$(git worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')"
[[ -n "$stack_home" ]] || stack_home="$PWD"
if [[ "$stack_home" != "$(git rev-parse --show-toplevel 2>/dev/null)" ]]; then
  echo "This is a git worktree: task commands run this branch's code against the one live stack owned by $stack_home."
fi
if [[ -f "$stack_home/.kube/config" ]]; then
  echo "Project kubeconfig present; reach the cluster only with task kube -- <args>."
else
  echo "No project kubeconfig yet: task up creates the cluster and writes it."
fi
exit 0
