#!/usr/bin/env bash
# Prerequisites check for the Mac: tools and versions, Docker Desktop
# resources and sign-in, Ollama and its models, proxy variables, free ports
# and the pre-commit git hook.
#
# Usage: scripts/doctor-prereqs.sh [--json]
# Exit code: 0 when no check failed, 1 otherwise. WARN never fails.
# Read-only: it changes nothing on the machine.
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/lib/common.sh"

for arg in "$@"; do
  case "$arg" in
    --json) JSON_OUTPUT=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL  jq is required: brew install jq" >&2
  exit 1
fi

# Expected values. See docs/adr/0002-toolchain-versions-and-pinning.md.
DOCKER_MIN_CPUS=8
DOCKER_MIN_MEMORY_MIB=12000
DOCKER_MIN_SWAP_MIB=2000
DOCKER_MIN_DISK_MIB=100000
REQUIRED_MODELS=("gemma4:12b" "gemma4:e4b")
OLLAMA_MAX_MODEL_GB=10   # warn when a loaded model is larger than this (GB)
OLLAMA_URL="http://127.0.0.1:11434"
# CLUSTER_NAME comes from scripts/lib/common.sh
CLUSTER_PORTS=(8080 7233)   # published by the k3d cluster once it runs
FREE_PORTS=(8080 4000 7233 5432)
DOCKER_SETTINGS="$HOME/Library/Group Containers/group.com.docker/settings-store.json"

# --- Tools -----------------------------------------------------------------
# mise.toml pins every command line tool exactly; scripts/lib/common.sh puts the
# pinned versions on PATH. Docker Desktop and Ollama are desktop apps, checked
# against a minimum version.

if command -v mise >/dev/null 2>&1; then
  check_pass mise "$(first_version "$(mise --version 2>/dev/null)")"
else
  check_fail mise "not installed: brew install mise, then mise install in this repo"
fi

# pinned_version TOOL: the exact version mise.toml pins for TOOL.
pinned_version() {
  sed -n "s/^$1[[:space:]]*=[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$REPO_ROOT/mise.toml" | head -n1
}

# check_pinned TOOL COMMAND VERSION_COMMAND...: the installed version equals the pin.
check_pinned() {
  local name="$1" cmd="$2" want version
  shift 2
  want="$(pinned_version "$name")"
  if [[ -z "$want" ]]; then
    check_fail "$name" "no pin in mise.toml"
    return
  fi
  if ! command -v "$cmd" >/dev/null 2>&1; then
    check_fail "$name" "not installed, expected $want: mise install"
    return
  fi
  version="$(first_version "$("$@" 2>/dev/null || true)")" # unreadable: fails below
  if [[ "$version" == "$want" ]]; then
    check_pass "$name" "$version"
  else
    check_fail "$name" "found ${version:-unknown}, expected $want: mise install"
  fi
}

# check_min NAME COMMAND MIN_VERSION VERSION_COMMAND...
check_min() {
  local name="$1" cmd="$2" min="$3" version
  shift 3
  if ! command -v "$cmd" >/dev/null 2>&1; then
    check_fail "$name" "not installed: see docs/prerequisites.md"
    return
  fi
  version="$(first_version "$("$@" 2>/dev/null || true)")" # unreadable: warned below
  if [[ -z "$version" ]]; then
    check_warn "$name" "installed, version not readable"
  elif version_ge "$version" "$min"; then
    check_pass "$name" "$version"
  else
    check_fail "$name" "$version is older than $min"
  fi
}

check_min docker docker 29.0 docker version --format '{{.Client.Version}}'
check_min ollama ollama 0.40 ollama --version

check_pinned k3d            k3d            k3d version
check_pinned kubectl        kubectl        kubectl version --client
check_pinned helm           helm           helm version --short
check_pinned terraform      terraform      terraform version
check_pinned tflint         tflint         tflint --version
check_pinned terraform-docs terraform-docs terraform-docs --version
check_pinned conftest       conftest       conftest --version
check_pinned task           task           task --version
check_pinned jq             jq             jq --version
check_pinned yq             yq             yq --version
check_pinned shellcheck     shellcheck     shellcheck --version
check_pinned ruff           ruff           ruff --version
check_pinned actionlint     actionlint     actionlint --version
check_pinned pre-commit     pre-commit     pre-commit --version
check_pinned gitleaks       gitleaks       gitleaks version
check_pinned temporal       temporal       temporal --version

# --- Docker Desktop --------------------------------------------------------

if docker info >/dev/null 2>&1; then
  check_pass docker-running "$(docker info --format '{{.OperatingSystem}}')"

  if [[ -r "$DOCKER_SETTINGS" ]]; then
    settings="$(jq -c '{Cpus, MemoryMiB, SwapMiB, DiskSizeMiB, KubernetesEnabled}' "$DOCKER_SETTINGS")"
    cpus="$(jq -r '.Cpus // 0' <<<"$settings")"
    mem="$(jq -r '.MemoryMiB // 0' <<<"$settings")"
    swap="$(jq -r '.SwapMiB // 0' <<<"$settings")"
    disk="$(jq -r '.DiskSizeMiB // 0' <<<"$settings")"
    kube="$(jq -r '.KubernetesEnabled // false' <<<"$settings")"
  else
    # Older or unusual installs: fall back to what the engine reports.
    cpus="$(docker info --format '{{.NCPU}}')"
    mem="$(( $(docker info --format '{{.MemTotal}}') / 1024 / 1024 + 256 ))"
    swap="" disk="" kube=""
  fi

  if (( cpus >= DOCKER_MIN_CPUS )); then
    check_pass docker-cpus "$cpus CPUs"
  else
    check_fail docker-cpus "$cpus CPUs, need $DOCKER_MIN_CPUS: Docker Desktop, Settings, Resources"
  fi

  if (( mem >= DOCKER_MIN_MEMORY_MIB )); then
    check_pass docker-memory "$mem MiB"
  else
    check_fail docker-memory "$mem MiB, need about 12 GB: Docker Desktop, Settings, Resources"
  fi

  if [[ -n "$swap" ]]; then
    if (( swap >= DOCKER_MIN_SWAP_MIB )); then
      check_pass docker-swap "$swap MiB"
    else
      check_warn docker-swap "$swap MiB, 2 GB recommended"
    fi
  fi

  if [[ -n "$disk" ]]; then
    if (( disk >= DOCKER_MIN_DISK_MIB )); then
      check_pass docker-disk "$(( disk / 1024 )) GB limit"
    else
      check_fail docker-disk "$(( disk / 1024 )) GB limit, need at least $(( DOCKER_MIN_DISK_MIB / 1024 )) GB"
    fi
  fi

  # Signed in to an organization, Docker Desktop applies its registry rules and
  # can refuse images ("image access restricted"). Only the
  # server names of stored logins are read, never the credentials.
  if command -v docker-credential-desktop >/dev/null 2>&1; then
    if docker-credential-desktop list 2>/dev/null | jq -e 'keys | any(test("index\\.docker\\.io"))' >/dev/null 2>&1; then
      check_warn docker-signin "signed in to Docker Hub; an organization's registry rules may block images (docs/prerequisites.md#registry-access)"
    else
      check_pass docker-signin "not signed in to Docker Hub"
    fi
  fi

  if [[ "$kube" == "true" ]]; then
    check_fail docker-kubernetes "Docker Desktop's Kubernetes is on; turn it off in Settings, Kubernetes"
  elif [[ "$kube" == "false" ]]; then
    check_pass docker-kubernetes "Docker Desktop's Kubernetes is off"
  else
    check_warn docker-kubernetes "cannot read Docker Desktop settings; make sure its Kubernetes is off"
  fi
else
  check_fail docker-running "Docker is not running: open Docker Desktop"
fi

# --- Ollama ----------------------------------------------------------------

if tags="$(curl -fsS --noproxy '*' --max-time 5 "$OLLAMA_URL/api/tags" 2>/dev/null)"; then
  check_pass ollama-running "answering on $OLLAMA_URL"
  for model in "${REQUIRED_MODELS[@]}"; do
    if jq -e --arg m "$model" 'any(.models[]; .name == $m)' <<<"$tags" >/dev/null; then
      check_pass "model $model" "present"
    else
      check_fail "model $model" "missing: ollama pull $model"
    fi
  done

  # A server started while a proxy was set keeps it, and its model pulls then fail.
  pid="$(pgrep -f 'ollama serve' | head -n1 || true)" # Ollama not running as a process
  if [[ -n "$pid" ]] && ps -wwE -p "$pid" -o command= 2>/dev/null | grep -Eqi '(^| )(https?|all)_proxy='; then
    check_warn ollama-proxy "the running Ollama server kept old proxy variables and pulls may fail: task stop:ollama, then task up"
  else
    check_pass ollama-proxy "no proxy variables"
  fi

  # A loaded model above the threshold may starve the k3d cluster of memory.
  if ps_json="$(curl -fsS --noproxy '*' --max-time 5 "$OLLAMA_URL/api/ps" 2>/dev/null)"; then
    big="$(jq -r --argjson max "$OLLAMA_MAX_MODEL_GB" \
      '[.models[]? | select(.size > ($max * 1073741824)) | "\(.name) (\((.size / 1073741824 * 10 | round) / 10) GiB)"] | join(", ")' <<<"$ps_json")"
    if [[ -z "$big" ]]; then
      check_pass ollama-loaded "no loaded model above ${OLLAMA_MAX_MODEL_GB} GB"
    else
      check_warn ollama-loaded "loaded model above ${OLLAMA_MAX_MODEL_GB} GB: $big; the cluster may run short of memory (task stop:ollama)"
    fi
  fi
else
  check_fail ollama-running "no answer on $OLLAMA_URL: open the Ollama app"
fi

# --- Proxy -----------------------------------------------------------------

proxy_vars=()
for var in HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy; do
  [[ -n "${!var:-}" ]] && proxy_vars+=("$var")
done
if (( ${#proxy_vars[@]} == 0 )); then
  check_pass proxy "no proxy variables in this shell"
else
  check_warn proxy "${proxy_vars[*]} set; image pulls and pod traffic may break (docs/prerequisites.md)"
fi

# --- Ports -----------------------------------------------------------------

cluster_running=0
if docker info >/dev/null 2>&1 \
  && [[ -n "$(docker ps -q --filter "label=k3d.cluster=$CLUSTER_NAME" 2>/dev/null)" ]]; then
  cluster_running=1
fi

for port in "${FREE_PORTS[@]}"; do
  if ! lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    check_pass "port $port" "free"
  elif (( cluster_running )) && [[ " ${CLUSTER_PORTS[*]} " == *" $port "* ]]; then
    check_pass "port $port" "used by the $CLUSTER_NAME cluster"
  else
    owner="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null | awk 'NR==2 {print $1}')"
    check_fail "port $port" "in use by ${owner:-another process}"
  fi
done

# --- Checks before commit --------------------------------------------------

hooks_dir="$(git -C "$REPO_ROOT" rev-parse --git-path hooks 2>/dev/null || true)"
[[ -n "$hooks_dir" && "$hooks_dir" != /* ]] && hooks_dir="$REPO_ROOT/$hooks_dir"
if [[ -n "$hooks_dir" ]] && grep -q pre-commit "$hooks_dir/pre-commit" 2>/dev/null; then
  check_pass pre-commit-hook "installed; every commit runs task ci -- --staged"
else
  check_warn pre-commit-hook "not installed, commits skip the lint and secret scan: pre-commit install"
fi

finish_checks
