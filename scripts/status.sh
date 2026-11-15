#!/usr/bin/env bash
# Show the cluster, its pods, the loaded Ollama models and the URLs.
# Usage: scripts/status.sh      (task status)
# Read-only. Exit code is 0 even when parts are stopped; task doctor judges health.
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd docker k3d kubectl jq curl

printf '== Cluster %s\n' "$CLUSTER_NAME"
if ! docker info >/dev/null 2>&1; then
  echo "Docker is not running"
else
  state="$(cluster_state)"
  echo "state: $state"
  if [[ "$state" == "running" && -f "$KUBECONFIG" ]]; then
    kc get nodes -o wide
    printf '\n== Pods\n'
    kc get pods -A
  fi
fi

printf '\n== Ollama\n'
if ollama_answering; then
  curl -fsS --noproxy '*' --max-time 5 "$OLLAMA_URL/api/ps" \
    | jq -r '"loaded models: " + (if (.models | length) == 0 then "none" else ([.models[].name] | join(", ")) end)'
else
  echo "not running"
fi

printf '\n== URLs\n'
echo "LiteLLM gateway & UI: http://litellm.localhost:8080 (Admin UI: http://litellm.localhost:8080/ui)"
echo "Temporal Web UI:      http://temporal.localhost:8080 (phase 5)"
echo "Temporal gRPC:        localhost:7233 (phase 5)"
echo "Ollama:               $OLLAMA_URL"
