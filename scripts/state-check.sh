#!/usr/bin/env bash
# Checks that Terraform state holds no secret values. Prints only a count and,
# on failure, resource addresses and attribute names; never a value.
#
# Usage: scripts/state-check.sh [--json] [STATE_FILE]      (task state:check)
#   STATE_FILE defaults to $STATE_FILE, then the stack home's state (scripts/lib/common.sh)
# Rules (a finding each):
#   1. a kubernetes_secret_v1 with a non-empty data, data_wo, binary_data or string_data
#   2. any managed (non-ephemeral) random_password resource
#   3. any attribute whose key matches password|secret|token|master_key|api_key
#      (case-insensitive) with a non-empty string value, unless it is an obvious
#      reference (see ALLOW below)
# Exit code: 0 for PASS or WARN (no state yet), 1 on FAIL.
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd jq

state_file="${STATE_FILE:-$TF_STATE_FILE}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      JSON_OUTPUT=1
      shift
      ;;
    -*) die "unknown argument: $1 (usage: scripts/state-check.sh [--json] [STATE_FILE])" ;;
    *)
      state_file="$1"
      shift
      ;;
  esac
done

if [[ ! -f "$state_file" ]]; then
  check_warn "tfstate secrets" "no state yet: nothing to check"
  finish_checks
  exit $?
fi

# ALLOW: key names that hold a reference, not a value (secret_name, data_wo_revision,
# secret_key_ref ...). Everything else matching the pattern is a finding.
findings="$(jq -r '
  def addr: (if .module then .module + "." else "" end) + .type + "." + .name;
  def allowed: test("(_name|_names|_revision|_version|_ref|_namespace)$"; "i");
  [ .resources[]? | . as $r
    | ($r | addr) as $a
    | $r.instances[]?
    | ($a + (if .index_key == null then "" else "[" + (.index_key | tojson) + "]" end)) as $ia
    | (.attributes // {}) as $at
    | (
        if $r.mode == "managed" and $r.type == "random_password" then
          "\($ia)\trandom_password in state"
        else empty end
      ),
      (
        if $r.mode == "managed" and $r.type == "kubernetes_secret_v1" then
          ("data", "data_wo", "binary_data", "string_data") as $f
          | select(($at[$f] // null) != null and $at[$f] != {} and $at[$f] != "")
          | "\($ia)\t\($f)"
        else empty end
      ),
      (
        $at | paths(type == "string" and length > 0) as $p
        | ([$p[] | select(type == "string")] | last // "") as $k
        | select($k | test("password|secret|token|master_?key|api_?key|credential|private_key"; "i"))
        | select($k | allowed | not)
        | "\($ia)\t\($p | map(tostring) | join("."))"
      )
  ] | unique | .[]
' "$state_file")" || die "cannot parse $state_file as Terraform state JSON"

if [[ -z "$findings" ]]; then
  check_pass "tfstate secrets" "0 secret-shaped values in state"
else
  count="$(grep -c . <<<"$findings" | tr -d ' ')"
  detail="$count secret-shaped value(s) in state (names only): $(awk -F'\t' '{printf "%s%s %s", sep, $1, $2; sep="; "}' <<<"$findings")"
  check_fail "tfstate secrets" "$detail; fix the module (ephemeral + write-only), then see docs/secrets.md"
fi
finish_checks
