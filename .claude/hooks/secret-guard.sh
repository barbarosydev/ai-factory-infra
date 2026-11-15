#!/usr/bin/env bash
# PreToolUse hook for Write, Edit and MultiEdit: block content that looks like a
# key, token or password before it reaches a file. Uses the same gitleaks rules
# as pre-commit and CI. Exit 2 blocks the write and tells Claude why.
set -euo pipefail

command -v gitleaks >/dev/null 2>&1 || exit 0   # task doctor:prereqs flags a missing gitleaks
command -v jq >/dev/null 2>&1 || exit 0

payload="$(cat)"
content="$(jq -r '
  .tool_input
  | [.content, .new_string, (.edits // [] | .[].new_string)]
  | map(select(. != null))
  | join("\n")
' <<<"$payload")"

[[ -z "$content" ]] && exit 0

if ! printf '%s' "$content" | gitleaks stdin --no-banner --redact --log-level error --exit-code 1 >/dev/null 2>&1; then
  file="$(jq -r '.tool_input.file_path // "the file"' <<<"$payload")"
  echo "Blocked by .claude/hooks/secret-guard.sh: the content for $file looks like a secret (gitleaks)." >&2
  echo "Secrets never go into files. Generate them in the cluster or pass them at run time; see docs/secrets.md." >&2
  exit 2
fi
