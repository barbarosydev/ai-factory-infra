#!/usr/bin/env bash
# PreToolUse hook for Bash: keep commits and pushes off main.
# Work happens on a branch and reaches main through a pull request. The IDE once
# switched this checkout to main in the middle of a phase, so the branch is
# checked at the moment of the commit, not trusted from earlier.
# Blocks (exit 2, reason on stderr): `git commit` while main is checked out, and
# `git push` while on main or with main as the target. Tests: tests/hooks/run.sh
set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

cmd="$(jq -r '.tool_input.command // empty')"
# Only lines that run git commit or git push (also with -C <dir> or -c k=v first).
git_sub='(^|[;&|(`[:space:]])git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+'
grep -Eq "${git_sub}(commit|push)([[:space:]]|$)" <<<"$cmd" || exit 0

branch="$(git -C "${CLAUDE_PROJECT_DIR:-.}" branch --show-current 2>/dev/null || true)"

if [[ "$branch" == "main" ]]; then
  echo "Blocked by .claude/hooks/branch-guard.sh: main is checked out (did the IDE switch branches?)." >&2
  echo "Run git status -sb, switch back to your work branch, then commit or push from there." >&2
  exit 2
fi

if grep -Eq "${git_sub}push([[:space:]].*)?[[:space:]](origin[[:space:]]+)?([^[:space:]]*:)?(refs/heads/)?main([[:space:]]|$)" <<<"$cmd"; then
  echo "Blocked by .claude/hooks/branch-guard.sh: never push to main; push your branch and open a pull request." >&2
  exit 2
fi
exit 0
