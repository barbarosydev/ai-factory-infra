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
    printf '\n== Resource Use (Docker & Pods)\n'
    cids=()
    while IFS= read -r cid; do
      [[ -n "$cid" ]] && cids+=("$cid")
    done < <(docker ps -q --filter "label=k3d.cluster=$CLUSTER_NAME" 2>/dev/null || true)
    if (( ${#cids[@]} > 0 )); then
      docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}' "${cids[@]}" 2>/dev/null || true
    fi
    if kc top pods -n ai-platform >/dev/null 2>&1; then
      printf '\n'
      kc top pods -n ai-platform
    fi
  fi
fi

printf '\n== Ollama\n'
if ollama_answering; then
  curl -fsS --noproxy '*' --max-time 5 "$OLLAMA_URL/api/ps" \
    | jq -r '"loaded models: " + (if (.models | length) == 0 then "none" else ([.models[] | "\(.name) (\((.size / 1073741824 * 10 | round) / 10) GiB)"] | join(", ")) end)'
else
  echo "not running"
fi

printf '\n== URLs\n'
echo "LiteLLM gateway & UI: http://litellm.localhost:8080 (Admin UI: http://litellm.localhost:8080/ui)"
echo "Temporal Web UI:      http://temporal.localhost:8080 (Workflows: http://temporal.localhost:8080/namespaces/default/workflows)"
echo "Temporal gRPC:        localhost:7233"
echo "Ollama:               $OLLAMA_URL"
