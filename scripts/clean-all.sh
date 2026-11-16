#!/usr/bin/env bash
# Delete the k3d cluster, project kubeconfig, Terraform state and provider caches,
# and optionally remove the Ollama models after a confirmation prompt.
#
# Usage: scripts/clean-all.sh [--keep-models | --remove-models]      (task clean:all)
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

model_action="ask"
for arg in "$@"; do
  case "$arg" in
    --keep-models) model_action="keep" ;;
    --remove-models) model_action="remove" ;;
    *) die "unknown argument: $arg (usage: scripts/clean-all.sh [--keep-models|--remove-models])" ;;
  esac
done

"$REPO_ROOT/scripts/cluster-clean.sh"

tf_dir="$REPO_ROOT/terraform/environments/local"
rm -rf "$tf_dir/.terraform" "$REPO_ROOT/.tflint.d"
info "removed Terraform provider caches (.terraform.lock.hcl kept)"

if [[ "$model_action" == "ask" && -t 0 ]]; then
  printf 'Also remove Ollama models (gemma4:12b, gemma4:e4b, ~17 GB to re-pull)? [y/N] '
  read -r reply
  if [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    model_action="remove"
  else
    model_action="keep"
  fi
fi

if [[ "$model_action" == "remove" ]]; then
  if command -v ollama >/dev/null 2>&1 && ollama_answering; then
    for m in gemma4:12b gemma4:e4b; do
      info "removing Ollama model $m"
      ollama rm "$m" || true
    done
  else
    warn "Ollama is not running; skipped removing models"
  fi
else
  info "kept Ollama models (gemma4:12b, gemma4:e4b)"
fi
