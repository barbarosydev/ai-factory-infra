#!/usr/bin/env bash
# Run kubectl against the project kubeconfig only, pinned to the k3d-ai-factory context.
# Usage: scripts/kube.sh get pods -n ai-platform     (or: task kube -- get pods -n ai-platform)
# It can never reach a cluster in your global kubeconfig, such as AKS.
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd kubectl

[[ -f "$KUBECONFIG" ]] || die "no project kubeconfig at .kube/config yet: run task up"

exec kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" "$@"
