#!/usr/bin/env bash
# PreToolUse hook for Bash: keep the read-only agents read-only.
# The agents in .claude/agents/ need Bash to run checks, and Claude Code cannot
# narrow Bash to single commands in an agent's tool list. This hook does it: when
# the call comes from one of those agents (hook input agent_type), commands that
# change the cluster, Terraform, git, GitHub or files are blocked (exit 2, reason
# on stderr). The main conversation and other agents are not affected.
# Tests: tests/hooks/run.sh
set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"
agent="$(jq -r '.agent_type // empty' <<<"$input")"
case "$agent" in
  terraform-reviewer | k8s-troubleshooter | version-security-auditor | platform-verifier) ;;
  *) exit 0 ;;
esac
cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"

# A command word at the start of the line or after ; & | ( ` or whitespace.
b='(^|[;&|(`[:space:]])'
mutating=(
  "${b}task[[:space:]]+(up|apply|restart|down|clean|stop)([:[:space:]]|$)"
  "${b}task[[:space:]]+kube[[:space:]]+--[[:space:]]+(.*[[:space:]])?(apply|create|delete|edit|patch|replace|scale|set|rollout|exec|run|cp|label|annotate|cordon|uncordon|drain|taint)([[:space:]]|$)"
  "${b}kubectl[[:space:]]+(.*[[:space:]])?(apply|create|delete|edit|patch|replace|scale|set|rollout|exec|run|cp|label|annotate|cordon|uncordon|drain|taint)([[:space:]]|$)"
  "${b}terraform[[:space:]]+(.*[[:space:]])?(apply|destroy|import|taint|untaint)([[:space:]]|$)"
  "${b}helm[[:space:]]+(install|upgrade|uninstall|rollback|delete)([[:space:]]|$)"
  "${b}k3d[[:space:]]+(cluster|node|image|registry)[[:space:]]+(create|delete|start|stop|edit|import)([[:space:]]|$)"
  "${b}ollama[[:space:]]+(pull|rm|run|stop|create|cp|push)([[:space:]]|$)"
  "${b}git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+(add|commit|push|rm|mv|reset|checkout|switch|restore|stash|merge|rebase|cherry-pick|revert|tag|clean|worktree|pull|fetch)([[:space:]]|$)"
  "${b}gh[[:space:]]+(pr|issue|release|repo|workflow|run)[[:space:]]+(create|merge|close|edit|delete|comment|review|reopen|rerun|cancel|run)([[:space:]]|$)"
  "${b}gh[[:space:]]+api[[:space:]]+(.*[[:space:]])?(-X|--method)[[:space:]]*(POST|PUT|PATCH|DELETE)"
  "${b}(rm|mv|truncate|tee|chmod|chown)[[:space:]]"
  "${b}sed[[:space:]]+(.*[[:space:]])?-i"
)
for re in "${mutating[@]}"; do
  if grep -Eq "$re" <<<"$cmd"; then
    echo "Blocked by .claude/hooks/agent-guard.sh: the $agent agent is read-only and may not run commands that change the cluster, Terraform, git, GitHub or files." >&2
    echo "Report the finding and the command you would run; the main conversation decides." >&2
    exit 2
  fi
done
exit 0
