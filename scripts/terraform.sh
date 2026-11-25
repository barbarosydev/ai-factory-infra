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
# In the main checkout TF_STATE_FILE is already the backend's default "terraform.tfstate";
# passing it as an absolute -backend-config path makes Terraform's local backend truncate
# the existing state file to 0 bytes during init -reconfigure.
export TF_VAR_kubeconfig_path="$KUBECONFIG"
tf_dir_real="$(cd "$tf_dir" && pwd -P)"
state_dir_real="$(cd "$(dirname "$TF_STATE_FILE")" 2>/dev/null && pwd -P || true)" # missing dir: treated as non-local path
init_args=(-input=false -upgrade=false -reconfigure)
if [[ -z "$state_dir_real" || "$state_dir_real/$(basename "$TF_STATE_FILE")" != "$tf_dir_real/terraform.tfstate" ]]; then
  init_args+=(-backend-config="path=$TF_STATE_FILE")
fi
terraform -chdir="$tf_dir" init "${init_args[@]}" >/dev/null

# wait_jobs JOB_NAMES: wait up to 300s for each Job (job/<name>) in ai-platform
# to complete. A Job deleted by its ttlSecondsAfterFinished before or during the
# wait had already finished and is skipped.
wait_jobs() {
  local job
  for job in $1; do
    if ! kc wait --for=condition=complete "$job" -n ai-platform --timeout=300s >/dev/null 2>&1; then
      # Finished Jobs are deleted by their TTL; one that vanished mid-wait had finished.
      kc get "$job" -n ai-platform >/dev/null 2>&1 || continue
      warn "$job did not complete; its status and last log lines follow (no Secret values)"
      kc get "$job" -n ai-platform >&2 || true # diagnostics only
      kc logs "$job" -n ai-platform --tail=20 >&2 2>&1 || true # diagnostics only
      die "$job failed or timed out after 300s: task kube -- describe $job -n ai-platform"
    fi
  done
}

if [[ "$action" == "plan" ]]; then
  terraform -chdir="$tf_dir" plan -input=false "$@"
else
  info "applying Terraform in ${tf_dir#"$REPO_ROOT"/}"
  terraform -chdir="$tf_dir" apply -input=false -auto-approve "$@"
  if kc get deployment/cnpg-cloudnative-pg -n ai-platform >/dev/null 2>&1; then
    kc rollout status deployment/cnpg-cloudnative-pg -n ai-platform --timeout=300s >/dev/null
  fi
  if kc get cluster.postgresql.cnpg.io/ai-postgres-cluster -n ai-platform >/dev/null 2>&1; then
    info "waiting for PostgreSQL cluster ai-postgres-cluster to be Ready"
    kc wait --for=condition=Ready cluster.postgresql.cnpg.io/ai-postgres-cluster -n ai-platform --timeout=300s
  fi
  if kc get deployment/litellm -n ai-platform >/dev/null 2>&1; then
    info "waiting for LiteLLM deployment and virtual key bootstrap"
    kc rollout status deployment/litellm -n ai-platform --timeout=300s
    # The Jobs carry no instance label, so select them by name. None is fine (keys disabled or TTL expired).
    all_jobs="$(kc get job -n ai-platform -o name)"
    litellm_jobs="$(grep '/litellm-' <<<"$all_jobs" || true)" # no match: no Jobs
    wait_jobs "$litellm_jobs"
  fi
  if kc get deployment/temporal-frontend -n ai-platform >/dev/null 2>&1; then
    info "waiting for Temporal schema/namespace Jobs and server deployments"
    # Completed Jobs are deleted after ttlSecondsAfterFinished (86400s); none left is fine on re-apply.
    temporal_jobs="$(kc get job -l app.kubernetes.io/instance=temporal -n ai-platform -o name)"
    wait_jobs "$temporal_jobs"
    for deploy in temporal-frontend temporal-history temporal-matching temporal-worker temporal-web; do
      kc rollout status "deployment/$deploy" -n ai-platform --timeout=300s
    done
  fi
  if kc get deployment/phoenix -n ai-platform >/dev/null 2>&1; then
    info "waiting for Arize Phoenix deployment"
    kc rollout status deployment/phoenix -n ai-platform --timeout=300s
  fi
fi
