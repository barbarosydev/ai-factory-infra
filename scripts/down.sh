#!/usr/bin/env bash
# Stop the stack and keep all data: stop the cluster and unload Ollama models.
# Usage: scripts/down.sh      (task down)
# Safe to repeat: a stopped stack is a success.
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

"$REPO_ROOT/scripts/cluster-stop.sh"
"$REPO_ROOT/scripts/ollama.sh" unload
info "down: data is kept; task up resumes"
