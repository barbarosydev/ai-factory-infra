#!/usr/bin/env bash
# Stop the k3d cluster and keep its data; scripts/cluster-setup.sh resumes it.
# Usage: scripts/cluster-stop.sh      (task stop:cluster, task down)
# Safe to repeat: a stopped or missing cluster is a success.
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd docker k3d jq

if ! docker info >/dev/null 2>&1; then
  info "Docker is not running, so the cluster is already stopped"
  exit 0
fi

case "$(cluster_state)" in
  absent) info "cluster $CLUSTER_NAME does not exist, nothing to stop" ;;
  stopped) info "cluster $CLUSTER_NAME is already stopped" ;;
  running)
    info "stopping cluster $CLUSTER_NAME (data is kept)"
    k3d cluster stop "$CLUSTER_NAME"
    ;;
esac
