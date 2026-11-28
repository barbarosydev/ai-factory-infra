#!/usr/bin/env bash
# Inspect or follow logs for a local ai-factory platform component using the project kubeconfig only.
#
# Usage:
#   scripts/logs.sh <litellm|temporal|phoenix|postgres|ollama|cnpg> [kubectl/tail args...]
#   task logs -- litellm --tail=100 -f
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

target="${1:-}"
[[ -n "$target" ]] || die "usage: task logs -- <litellm|temporal|phoenix|postgres|ollama|cnpg> [--tail=100] [-f]"
shift

if [[ "$target" == "ollama" ]]; then
  log_file="$HOME/.ollama/logs/server.log"
  [[ -f "$log_file" ]] || die "Ollama server log not found at $log_file"
  tail_args=()
  has_lines=0
  for arg in "$@"; do
    case "$arg" in
      --tail=*)
        tail_args+=(-n "${arg#--tail=}")
        has_lines=1
        ;;
      -f | --follow)
        tail_args+=(-f)
        ;;
      *)
        tail_args+=("$arg")
        ;;
    esac
  done
  if [[ "$has_lines" -eq 0 ]]; then
    tail_args=(-n 100 "${tail_args[@]}")
  fi
  exec tail "${tail_args[@]}" "$log_file"
fi

require_cmd kubectl
[[ -f "$KUBECONFIG" ]] || die "no project kubeconfig at $KUBECONFIG yet: run task up"

has_tail=0
for arg in "$@"; do
  case "$arg" in
    --tail=* | --tail) has_tail=1 ;;
  esac
done

default_tail=()
if [[ "$has_tail" -eq 0 ]]; then
  if [[ "$target" == "temporal" ]]; then
    default_tail=(--tail=50)
  else
    default_tail=(--tail=100)
  fi
fi

case "$target" in
  litellm)
    kc logs -n ai-platform -l app.kubernetes.io/name=litellm "${default_tail[@]}" "$@"
    ;;
  phoenix)
    kc logs -n ai-platform -l app.kubernetes.io/name=phoenix "${default_tail[@]}" "$@"
    ;;
  temporal)
    kc logs -n ai-platform -l 'app.kubernetes.io/name=temporal,app.kubernetes.io/component!=database' \
      --prefix=true --max-log-requests=10 "${default_tail[@]}" "$@"
    ;;
  postgres)
    kc logs -n ai-platform -l cnpg.io/cluster=ai-postgres-cluster "${default_tail[@]}" "$@"
    ;;
  cnpg)
    kc logs -n ai-platform -l app.kubernetes.io/name=cloudnative-pg "${default_tail[@]}" "$@"
    ;;
  *)
    die "unknown service '$target' (choose: litellm, temporal, phoenix, postgres, ollama, cnpg)"
    ;;
esac
