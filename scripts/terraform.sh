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

# apply changes the shared stack: one at a time (plan only reads it).
if [[ "$action" == "apply" ]]; then
  stack_lock "task apply"
fi

[[ -f "$KUBECONFIG" ]] || die "project kubeconfig not found at $KUBECONFIG: run task up first"

tf_dir="$REPO_ROOT/terraform/environments/local"

info "initializing Terraform in ${tf_dir#"$REPO_ROOT"/}"
# State and kubeconfig live in STACK_HOME (the main checkout), also when this runs
# from a git worktree; see scripts/lib/common.sh.
export TF_VAR_kubeconfig_path="$KUBECONFIG"
terraform -chdir="$tf_dir" init -input=false -upgrade=false -reconfigure -backend-config="path=$TF_STATE_FILE" >/dev/null

if [[ "$action" == "plan" ]]; then
  terraform -chdir="$tf_dir" plan -input=false "$@"
else
  info "applying Terraform in ${tf_dir#"$REPO_ROOT"/}"
  terraform -chdir="$tf_dir" apply -input=false -auto-approve "$@"
  if kc get cluster.postgresql.cnpg.io/ai-postgres-cluster -n ai-platform >/dev/null 2>&1; then
    info "waiting for PostgreSQL cluster ai-postgres-cluster to be Ready"
    kc wait --for=condition=Ready cluster.postgresql.cnpg.io/ai-postgres-cluster -n ai-platform --timeout=300s
  fi
  if kc get deployment/litellm -n ai-platform >/dev/null 2>&1; then
    info "waiting for LiteLLM deployment and virtual key bootstrap"
    kc rollout status deployment/litellm -n ai-platform --timeout=300s
    # The Jobs carry no instance label, so select them by name. None is fine (keys disabled).
    all_jobs="$(kc get job -n ai-platform -o name)"
    litellm_jobs="$(grep '/litellm-' <<<"$all_jobs" || true)" # no match: no Jobs
    for job in $litellm_jobs; do
      if ! kc wait --for=condition=complete "$job" -n ai-platform --timeout=300s >/dev/null 2>&1; then
        # Finished Jobs are deleted by their TTL; one that vanished mid-wait had finished.
        kc get "$job" -n ai-platform >/dev/null 2>&1 || continue
        warn "$job did not complete; its status and last log lines follow (no Secret values)"
        kc get "$job" -n ai-platform >&2 || true # diagnostics only
        kc logs "$job" -n ai-platform --tail=20 >&2 2>&1 || true # diagnostics only
        die "$job failed or timed out after 300s: task kube -- describe $job -n ai-platform"
      fi
    done
  fi
  if kc get deployment/temporal-frontend -n ai-platform >/dev/null 2>&1; then
    info "waiting for Temporal schema/namespace Jobs and server deployments"
    kc wait --for=condition=complete job -l app.kubernetes.io/instance=temporal -n ai-platform --timeout=300s
    for deploy in temporal-frontend temporal-history temporal-matching temporal-worker temporal-web; do
      kc rollout status "deployment/$deploy" -n ai-platform --timeout=300s
    done
  fi
fi
