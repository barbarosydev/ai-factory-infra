#!/usr/bin/env bash
# PostToolUse hook for Write, Edit and MultiEdit: run terraform fmt on the edited
# .tf or .tfvars file and refresh terraform-docs if the directory has a README.md,
# so formatting and module docs never depend on the model remembering them.
set -euo pipefail

command -v terraform >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

file="$(jq -r '.tool_input.file_path // empty')"
case "$file" in
  *.tf | *.tfvars)
    if [[ -f "$file" ]]; then
      terraform fmt -no-color "$file" >/dev/null 2>&1 || true
      dir="$(dirname "$file")"
      if command -v terraform-docs >/dev/null 2>&1 && [[ -f "$dir/README.md" ]] && grep -q "BEGIN_TF_DOCS" "$dir/README.md" 2>/dev/null; then
        terraform-docs markdown table --output-file README.md --output-mode inject "$dir" >/dev/null 2>&1 || true
      fi
    fi
    ;;
esac
exit 0
