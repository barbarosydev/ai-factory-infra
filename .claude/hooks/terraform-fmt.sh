#!/usr/bin/env bash
# PostToolUse hook for Write, Edit and MultiEdit: run terraform fmt on the edited
# .tf or .tfvars file, so formatting never depends on the model remembering it.
set -euo pipefail

command -v terraform >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

file="$(jq -r '.tool_input.file_path // empty')"
case "$file" in
  *.tf | *.tfvars) [[ -f "$file" ]] && terraform fmt -no-color "$file" >/dev/null 2>&1 || true ;;
esac
exit 0
