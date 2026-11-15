#!/usr/bin/env bash
# Start Ollama, unload its models, or stop it. Ollama runs natively on the Mac
# (the macOS app) so it can use the GPU.
# Usage: scripts/ollama.sh start | unload | stop
#   start   open the Ollama app if the API does not answer, and wait for it   (task up)
#   unload  unload every loaded model from memory; the models stay on disk    (task down)
#   stop    unload the models, then quit the Ollama app                       (task stop:ollama)
# Safe to repeat.
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd curl jq

unload_models() {
  ollama_answering || { info "Ollama is not running, no models to unload"; return 0; }
  local models model
  models="$(curl -fsS --noproxy '*' --max-time 5 "$OLLAMA_URL/api/ps" | jq -r '.models[].name')"
  if [[ -z "$models" ]]; then
    info "no Ollama models are loaded"
    return 0
  fi
  while IFS= read -r model; do
    info "unloading $model"
    # keep_alive 0 asks the server to unload the model now.
    curl -fsS --noproxy '*' --max-time 30 "$OLLAMA_URL/api/generate" \
      -d "$(jq -cn --arg m "$model" '{model: $m, keep_alive: 0}')" >/dev/null
  done <<<"$models"
}

case "${1:-}" in
  start)
    if ollama_answering; then
      info "Ollama is running on $OLLAMA_URL"
    else
      info "starting the Ollama app"
      open -a Ollama
      wait_until 60 "Ollama on $OLLAMA_URL (open the Ollama app)" ollama_answering
      info "Ollama is running on $OLLAMA_URL"
    fi
    ;;
  unload)
    unload_models
    ;;
  stop)
    unload_models
    if pgrep -x Ollama >/dev/null 2>&1; then
      info "quitting the Ollama app"
      # The app's quit dialog cancels an AppleScript quit, so send TERM instead.
      pkill -TERM -x Ollama
    fi
    ollama_stopped() { ! ollama_answering; }
    wait_until 30 "Ollama to stop (it may run outside the app: check ps aux | grep 'ollama serve')" ollama_stopped
    info "Ollama is stopped"
    ;;
  *)
    echo "usage: $0 start | unload | stop" >&2
    exit 2
    ;;
esac
