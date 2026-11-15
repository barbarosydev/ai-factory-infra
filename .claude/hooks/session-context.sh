#!/usr/bin/env bash
# SessionStart hook: tell Claude where the checkout stands when a session starts.
# For SessionStart, whatever this prints on stdout is added to Claude's context,
# so it starts from facts (branch, uncommitted files) instead of guessing.
# Read-only and fast: git only, no Docker or cluster calls.
set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
branch="$(git branch --show-current 2>/dev/null)" || exit 0
changes="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"

echo "Checkout: branch ${branch:-detached HEAD}, ${changes} uncommitted file(s)."
if [[ "$branch" == "main" ]]; then
  echo "main is checked out: create a branch before changing files (branch-guard blocks commits on main)."
fi
if [[ -f .kube/config ]]; then
  echo "Project kubeconfig present; reach the cluster only with task kube -- <args>."
else
  echo "No project kubeconfig yet: task up creates the cluster and writes it."
fi
exit 0
