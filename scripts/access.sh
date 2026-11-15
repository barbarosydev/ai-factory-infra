#!/usr/bin/env bash
# Show Web UIs, API endpoints, secret names, and copy-to-clipboard / curl helpers.
# Never prints secret values to stdout (Layer 4); --copy pipes directly to pbcopy.
#
# Usage:
#   scripts/access.sh                        (task access)
#   scripts/access.sh --copy <target>        (task access -- --copy master|pm-agent|dev-agent|sec-agent)
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

copy_target=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --copy)
      [[ $# -ge 2 ]] || die "usage: task access -- --copy <master|pm-agent|dev-agent|sec-agent>"
      copy_target="$2"
      shift 2
      ;;
    *)
      die "unknown argument: $1 (usage: task access [-- --copy <master|pm-agent|dev-agent|sec-agent>])"
      ;;
  esac
done

if [[ -n "$copy_target" ]]; then
  require_cmd kubectl pbcopy base64
  [[ -f "$KUBECONFIG" ]] || die "project kubeconfig not found at $KUBECONFIG: run task up first"

  case "$copy_target" in
    master)
      secret_name="litellm-masterkey"
      secret_key="masterkey"
      ;;
    pm-agent | dev-agent | sec-agent)
      secret_name="litellm-${copy_target}-key"
      secret_key="api_key"
      ;;
    *)
      die "unknown copy target '$copy_target': choose master, pm-agent, dev-agent or sec-agent"
      ;;
  esac

  val="$(kc get secret "$secret_name" -n ai-platform -o "jsonpath={.data.${secret_key}}" 2>/dev/null || true)"
  [[ -n "$val" ]] || die "secret $secret_name ($secret_key) not found in namespace ai-platform: run task up first"
  printf '%s' "$val" | base64 -d | pbcopy
  info "copied $secret_name ($secret_key) to the macOS clipboard (value not printed)"
  exit 0
fi

cat <<'EOF'
== Web UIs & Endpoints
  LiteLLM Admin UI:      http://litellm.localhost:8080/ui
    Username:            admin
    Password:            stored in Secret litellm-masterkey (key: masterkey)
  LiteLLM Swagger UI:    http://litellm.localhost:8080/
  LiteLLM OpenAI API:    http://litellm.localhost:8080/v1
  Temporal Web UI:       http://temporal.localhost:8080  (phase 5, no auth in local sandbox)
  Temporal gRPC:         localhost:7233                  (phase 5, no auth in local sandbox)
  Ollama (host):         http://127.0.0.1:11434

== Kubernetes Secrets (namespace: ai-platform)
  Secret Name                        Key        Purpose
  ---------------------------------  ---------  ---------------------------------------------
  litellm-masterkey                  masterkey  LiteLLM Admin UI password & master API key
  litellm-pm-agent-key               api_key    Virtual key scoped to model route: pm-agent
  litellm-dev-agent-key              api_key    Virtual key scoped to model route: dev-agent
  litellm-sec-agent-key              api_key    Virtual key scoped to model route: sec-agent
  ai-postgres-litellm-credentials    password   PostgreSQL user 'litellm' (database: litellm)
  ai-postgres-temporal-credentials   password   PostgreSQL user 'temporal' (temporal DBs)

== Copy a Key to Clipboard (nothing printed to terminal)
  task access -- --copy master       # Admin UI password / master key
  task access -- --copy pm-agent     # pm-agent virtual key (gemma4:12b)
  task access -- --copy dev-agent    # dev-agent virtual key (gemma4:e4b)
  task access -- --copy sec-agent    # sec-agent virtual key (gemma4:e4b)

== Call LiteLLM API from your Mac
  task access -- --copy pm-agent
  curl -sS --noproxy '*' http://litellm.localhost:8080/v1/chat/completions \
    -H "Authorization: Bearer $(pbpaste)" \
    -H "Content-Type: application/json" \
    -d '{"model":"pm-agent","messages":[{"role":"user","content":"Hello!"}],"max_tokens":128}' \
    | jq -r '.choices[0].message.content'
EOF
