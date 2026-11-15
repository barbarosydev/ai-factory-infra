#!/usr/bin/env bash
# Run Terraform plan or apply for the local environment against the project cluster.
# Usage: scripts/terraform.sh <plan|apply> [extra terraform args...]
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd terraform

action="${1:-}"
case "$action" in
  plan | apply) shift ;;
  *) die "usage: scripts/terraform.sh <plan|apply> [args...]" ;;
esac

[[ -f "$KUBECONFIG" ]] || die "project kubeconfig not found at $KUBECONFIG: run task up first"

tf_dir="$REPO_ROOT/terraform/environments/local"

info "initializing Terraform in ${tf_dir#"$REPO_ROOT"/}"
terraform -chdir="$tf_dir" init -input=false -upgrade=false >/dev/null

if [[ "$action" == "plan" ]]; then
  terraform -chdir="$tf_dir" plan -input=false "$@"
else
  info "applying Terraform in ${tf_dir#"$REPO_ROOT"/}"
  terraform -chdir="$tf_dir" apply -input=false -auto-approve "$@"
  if kc get cluster.postgresql.cnpg.io/ai-postgres-cluster -n ai-platform >/dev/null 2>&1; then
    info "waiting for PostgreSQL cluster ai-postgres-cluster to be Ready"
    kc wait --for=condition=Ready cluster.postgresql.cnpg.io/ai-postgres-cluster -n ai-platform --timeout=300s
  fi
fi
