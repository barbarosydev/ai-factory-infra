#!/usr/bin/env bash
# Delete the k3d cluster, the project kubeconfig and the local Terraform state.
# All databases are lost; the next task up rebuilds everything from scratch.
# Usage: scripts/cluster-clean.sh      (task clean, which asks first)
# Safe to repeat: nothing to delete is a success.
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd docker k3d jq shasum

docker info >/dev/null 2>&1 || die "Docker is not running: open Docker Desktop"
before="$(user_kubeconfig_fingerprint)"

if [[ "$(cluster_state)" == "absent" ]]; then
  info "cluster $CLUSTER_NAME does not exist"
else
  info "deleting cluster $CLUSTER_NAME"
  # KUBECONFIG points at the project file (common.sh), so k3d only edits that one.
  k3d cluster delete "$CLUSTER_NAME"
fi

rm -f "$KUBECONFIG"
state_dir="$(dirname "$TF_STATE_FILE")"
rm -f "$state_dir"/terraform.tfstate "$state_dir"/terraform.tfstate.backup "$state_dir"/.terraform.tfstate.lock.info
info "removed the project kubeconfig and local Terraform state"

after="$(user_kubeconfig_fingerprint)"
[[ "$before" == "$after" ]] || die "your own kubeconfig changed during clean; check it with kubectx before doing anything else"
