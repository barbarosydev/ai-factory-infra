#!/usr/bin/env bash
# Create the k3d cluster, or resume it when it is stopped, then write the
# project kubeconfig and wait until the node and the ingress are ready.
# Usage: scripts/cluster-setup.sh      (task up runs it)
# Safe to repeat: on a running cluster it only refreshes the kubeconfig and checks readiness.
# Your global kubeconfig is never written; the script fails if it changes.
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_cmd docker k3d kubectl jq shasum curl

docker info >/dev/null 2>&1 || die "Docker is not running: open Docker Desktop"
before="$(user_kubeconfig_fingerprint)"

state="$(cluster_state)"
case "$state" in
  absent)
    info "creating cluster $CLUSTER_NAME from cluster/k3d-config.yaml"
    k3d cluster create --config "$K3D_CONFIG"
    ;;
  stopped)
    info "resuming cluster $CLUSTER_NAME"
    k3d cluster start "$CLUSTER_NAME" --wait --timeout 180s
    ;;
  running)
    info "cluster $CLUSTER_NAME is already running"
    ;;
esac

# Project kubeconfig: only the k3d-ai-factory context, readable by you alone.
mkdir -p "$REPO_ROOT/.kube"
chmod 700 "$REPO_ROOT/.kube"
tmp="$(mktemp "$REPO_ROOT/.kube/config.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
k3d kubeconfig get "$CLUSTER_NAME" >"$tmp"
chmod 600 "$tmp"
mv "$tmp" "$KUBECONFIG"
trap - EXIT

contexts="$(kubectl --kubeconfig "$KUBECONFIG" config get-contexts -o name)"
[[ "$contexts" == "$KUBE_CONTEXT" ]] || die "project kubeconfig should hold only $KUBE_CONTEXT, found: $contexts"

info "waiting for the node to be Ready"
wait_until 120 "the API server (task kube -- cluster-info)" kc get --raw /readyz
kc wait --for=condition=Ready node --all --timeout=120s >/dev/null

# Traefik is installed by k3s's Helm controller a little after the node is Ready.
info "waiting for CoreDNS and the Traefik ingress"
kc -n kube-system rollout status deployment/coredns --timeout=120s >/dev/null
wait_until 180 "the Traefik deployment (task kube -- -n kube-system get pods)" \
  kc -n kube-system get deployment/traefik
kc -n kube-system rollout status deployment/traefik --timeout=180s >/dev/null

# After a resume the old Ready states can linger for a few seconds, so also
# wait for what the stack really needs: k3d's host.k3d.internal record in
# CoreDNS (the route from pods to Ollama on the Mac) and an answer on port 8080.
host_record_present() {
  kc -n kube-system get configmap coredns -o jsonpath='{.data.NodeHosts}' | grep -q ' host\.k3d\.internal$'
}
ingress_answers() {
  [[ "$(curl -s --noproxy '*' --max-time 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/)" == "404" ]]
}
wait_until 120 "host.k3d.internal in CoreDNS (task kube -- -n kube-system get configmap coredns -o yaml)" host_record_present
# After a resume, kubelet and CoreDNS can take about 90 s to pick the record
# up. One probe pod waits inside the cluster until the name resolves (180 s).
info "waiting until pods can resolve host.k3d.internal"
# shellcheck disable=SC2016  # $i expands inside the pod, not here
probe_pod dns-wait 'i=0; until nslookup host.k3d.internal >/dev/null 2>&1; do
  i=$((i+1)); [ "$i" -ge 60 ] && exit 1; sleep 3; done' >/dev/null \
  || die "pods cannot resolve host.k3d.internal after 180s: task kube -- -n kube-system logs deployment/coredns"
wait_until 120 "Traefik on 127.0.0.1:8080 (task kube -- -n kube-system logs deployment/traefik)" ingress_answers

after="$(user_kubeconfig_fingerprint)"
[[ "$before" == "$after" ]] || die "your own kubeconfig changed during cluster setup; check it with kubectx before doing anything else"

info "cluster $CLUSTER_NAME is ready (task kube -- get nodes)"
