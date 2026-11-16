#!/usr/bin/env bash
# Lint everything: Terraform format, validate and tflint; shellcheck; ruff; JSON and YAML syntax;
# the Conftest policies in policy/; links and paths in the docs.
# Usage: scripts/lint.sh
# Exit code: 0 when every linter passes, 1 otherwise. Never changes a tracked file.
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

# lockfile_platforms FILE: every provider block needs hashes for darwin_arm64, linux_amd64 and
# linux_arm64. h1: hashes are not labelled by platform, so check offline what is checkable:
# at least three h1: and three zh: entries per provider (one each per platform).
# Failure names the provider and the command that fixes it.
# shellcheck disable=SC2317,SC2329  # called through run
lockfile_platforms() {
  awk '
    function finish() { if (prov != "" && (h1 < 3 || zh < 3)) { printf "%s has %d h1 and %d zh hashes, need at least 3 of each\n", prov, h1, zh; bad = 1 } }
    /^provider "/ { finish(); prov = $2; gsub(/"/, "", prov); h1 = 0; zh = 0 }
    /^[[:space:]]*"h1:/ { h1++ }
    /^[[:space:]]*"zh:/ { zh++ }
    END { finish(); if (prov == "") { print "no provider blocks found"; bad = 1 } exit bad }
  ' "$1" >&2 || {
    echo "fix: terraform -chdir=terraform/environments/local providers lock -platform=darwin_arm64 -platform=linux_amd64 -platform=linux_arm64" >&2
    return 1
  }
}

# --- Terraform -------------------------------------------------------------

tf_files="$(find terraform -name '*.tf' -not -path '*/.terraform/*' 2>/dev/null | head -n1 || true)" # no .tf files is fine
if [[ -z "$tf_files" ]]; then
  info "no Terraform files yet, skipping Terraform checks"
else
  require_cmd terraform tflint
  run "terraform fmt" terraform fmt -check -recursive -diff terraform

  # mise.toml is the one pin for the Terraform CLI; required_version must agree with it.
  # shellcheck disable=SC2317,SC2329  # called through run
  terraform_pin_matches() {
    local pin bad
    pin="$(sed -n 's/^terraform[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' mise.toml)"
    bad="$(grep -rL --include=versions.tf "required_version = \"= $pin\"" terraform/environments terraform/modules || true)" # no mismatch: empty
    [[ -n "$pin" && -z "$bad" ]] || {
      echo "required_version differs from the terraform pin ($pin) in mise.toml: $bad" >&2
      return 1
    }
  }
  run "terraform required_version matches mise.toml" terraform_pin_matches

  for env_dir in terraform/environments/*/; do
    [[ -n "$(find "$env_dir" -maxdepth 1 -name '*.tf' | head -n1)" ]] || continue
    run "terraform validate ${env_dir%/}" bash -c \
      "terraform -chdir='$env_dir' init -backend=false -input=false >/dev/null && terraform -chdir='$env_dir' validate -no-color"
    lock_file="${env_dir}.terraform.lock.hcl"
    if [[ -f "$lock_file" ]]; then
      run "terraform lockfile platforms ${env_dir%/}" lockfile_platforms "$lock_file"
    fi
  done

  run "tflint init" tflint --init --config "$REPO_ROOT/.tflint.hcl"
  run "tflint" tflint --recursive --chdir terraform --config "$REPO_ROOT/.tflint.hcl"

  if command -v terraform-docs >/dev/null 2>&1; then
    for tf_dir in terraform/environments/*/ terraform/modules/*/; do
      [[ -n "$(find "$tf_dir" -maxdepth 1 -name '*.tf' | head -n1)" ]] || continue
      run "terraform-docs ${tf_dir%/}" terraform-docs markdown table --output-file README.md --output-mode inject --output-check "${tf_dir%/}"
    done
  fi

  run "terraform helm templates (.yaml.tftpl)" "$REPO_ROOT/scripts/lib/validate_tftpl.py"

  # Module tests: mock providers, plan only; no cluster, Docker or state.
  # init writes a lock file into the module; remove it, because lock files belong to
  # environments only and terraform-docs would print its versions into the README.
  for mod_dir in terraform/modules/*/; do
    [[ -d "${mod_dir}tests" ]] || continue
    run "terraform test ${mod_dir%/}" bash -c \
      "terraform -chdir='$mod_dir' init -backend=false -input=false >/dev/null && terraform -chdir='$mod_dir' test -no-color >/dev/null"
    rm -f "${mod_dir}.terraform.lock.hcl"
  done
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

# --- Python ------------------------------------------------------------------

require_cmd ruff
py_files="$(tracked '*.py')"
if [[ -n "$py_files" ]]; then
  # shellcheck disable=SC2086  # one file per line, no spaces in our paths
  run "ruff check ($(wc -l <<<"$py_files" | tr -d ' ') files)" ruff check --quiet $py_files
  # shellcheck disable=SC2086
  run "ruff format --check" ruff format --check --quiet $py_files
fi

# --- JSON and YAML syntax --------------------------------------------------

require_cmd jq yq
# shellcheck disable=SC2317,SC2329  # called through run
yaml_ok() { yq eval 'true' "$1" >/dev/null; }
while IFS= read -r f; do
  [[ -n "$f" ]] && run "json $f" jq empty "$f"
done <<<"$(tracked '*.json')"
while IFS= read -r f; do
  [[ -n "$f" ]] && run "yaml $f" yaml_ok "$f"
done <<<"$(tracked '*.yml' '*.yaml')"

# --- Policies (policy/README.md) -------------------------------------------
# Conftest turns the hard rules into checks. Each namespace runs only against
# its own files; the .tf globs never match state or the module test folders.

require_cmd conftest
# ct ARGS...: quiet when the policy passes, shows the failures when it does not.
# shellcheck disable=SC2317,SC2329  # called through run
ct() {
  local out
  out="$(conftest test --no-color --policy policy "$@" 2>&1)" || {
    echo "$out" >&2
    return 1
  }
}
run "conftest verify (policy unit tests)" conftest verify --no-color --policy policy
# shellcheck disable=SC2046  # file lists are split on purpose
run "policy: write-only secrets, helm release contract" ct --namespace terraform.secrets --namespace terraform.helm \
  $(tracked 'terraform/modules/*/*.tf' 'terraform/environments/*/*.tf' | grep -v '/tests/')
run "policy: providers use the project kubeconfig" ct --namespace terraform.providers terraform/environments/local/providers.tf
run "policy: images pinned by digest" ct --namespace images terraform/environments/local/variables.tf cluster/k3d-config.yaml .mcp.json
run "policy: k3d binds to loopback only" ct --namespace k3d cluster/k3d-config.yaml
# shellcheck disable=SC2046
run "policy: workflows have a read-only token, actions pinned by SHA" ct --namespace github $(tracked '.github/workflows/*.yml')
run "policy: Claude Code deny rules and guard hooks" ct --namespace claude .claude/settings.json

# --- Workflows -------------------------------------------------------------

require_cmd actionlint
run "actionlint" actionlint -no-color

# --- Docs ------------------------------------------------------------------

run "doc links and paths" "$REPO_ROOT/scripts/lib/check_links.py"

exit "$failed"
