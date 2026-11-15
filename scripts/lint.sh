#!/usr/bin/env bash
# Lint everything: Terraform format, validate and tflint; shellcheck; Python, JSON and YAML syntax.
# Usage: scripts/lint.sh
# Exit code: 0 when every linter passes, 1 otherwise. Never changes a file.
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
cd "$REPO_ROOT"

failed=0
run() {
  local name="$1"
  shift
  if "$@"; then
    printf '%sPASS%s  %s\n' "$C_GREEN" "$C_RESET" "$name"
  else
    printf '%sFAIL%s  %s\n' "$C_RED" "$C_RESET" "$name"
    failed=1
  fi
}

# --- Terraform -------------------------------------------------------------

tf_files="$(find terraform -name '*.tf' -not -path '*/.terraform/*' 2>/dev/null | head -n1 || true)"
if [[ -z "$tf_files" ]]; then
  info "no Terraform files yet, skipping Terraform checks"
else
  require_cmd terraform tflint
  run "terraform fmt" terraform fmt -check -recursive -diff terraform

  for env_dir in terraform/environments/*/; do
    [[ -n "$(find "$env_dir" -maxdepth 1 -name '*.tf' | head -n1)" ]] || continue
    run "terraform validate ${env_dir%/}" bash -c \
      "terraform -chdir='$env_dir' init -backend=false -input=false >/dev/null && terraform -chdir='$env_dir' validate -no-color"
  done

  run "tflint init" tflint --init --config "$REPO_ROOT/.tflint.hcl"
  run "tflint" tflint --recursive --chdir terraform --config "$REPO_ROOT/.tflint.hcl"
fi

# --- Shell -----------------------------------------------------------------
# Plain loops, no mapfile: works with macOS's bash 3.2 too.

tracked() { git ls-files --cached --others --exclude-standard -- "$@"; }

require_cmd shellcheck
shell_files="$(tracked '*.sh')"
if [[ -n "$shell_files" ]]; then
  # shellcheck disable=SC2086  # one file per line, no spaces in our paths
  run "shellcheck ($(wc -l <<<"$shell_files" | tr -d ' ') files)" shellcheck -x $shell_files
fi

# --- Python (hooks) ------------------------------------------------------

while IFS= read -r f; do
  [[ -n "$f" ]] && run "python $f" python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read(), sys.argv[1])' "$f"
done <<<"$(tracked '*.py')"

# --- JSON and YAML syntax --------------------------------------------------

require_cmd jq yq
# shellcheck disable=SC2329  # called through run
yaml_ok() { yq eval 'true' "$1" >/dev/null; }
while IFS= read -r f; do
  [[ -n "$f" ]] && run "json $f" jq empty "$f"
done <<<"$(tracked '*.json')"
while IFS= read -r f; do
  [[ -n "$f" ]] && run "yaml $f" yaml_ok "$f"
done <<<"$(tracked '*.yml' '*.yaml')"

exit "$failed"
