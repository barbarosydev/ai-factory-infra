#!/usr/bin/env bash
# Phase 3 smoke test for CloudNativePG and PostgreSQL role/database isolation.
# Prints one PASS/WARN/FAIL line per check; never reads or prints Secret values.
#
# Usage: tests/smoke/postgres.sh [--json]      (task smoke:postgres)
# Exit code: 0 when no check failed.
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/../../scripts/lib/common.sh"
require_cmd kubectl jq

for arg in "$@"; do
  case "$arg" in
    --json) JSON_OUTPUT=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

NS="ai-platform"
PG_IMAGE="ghcr.io/cloudnative-pg/postgresql:16"

# --- Operator & Cluster ----------------------------------------------------

op_avail="$(kc get deployment cnpg-cloudnative-pg -n "$NS" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || true)"
if [[ "${op_avail:-0}" -ge 1 ]]; then
  check_pass "cnpg operator" "deployment Ready in $NS"
else
  check_fail "cnpg operator" "not Ready: task kube -- get pods -n $NS"
fi

cluster_ready="$(kc get cluster.postgresql.cnpg.io/ai-postgres-cluster -n "$NS" \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
cluster_status="$(kc get cluster.postgresql.cnpg.io/ai-postgres-cluster -n "$NS" \
  -o jsonpath='{.status.phase}' 2>/dev/null || true)"
if [[ "$cluster_ready" == "True" ]]; then
  check_pass "postgres cluster" "ai-postgres-cluster Ready ($cluster_status)"
else
  check_fail "postgres cluster" "not Ready (${cluster_status:-missing}): task kube -- get cluster -n $NS"
fi

# --- Databases -------------------------------------------------------------

dbs="$(kc get databases.postgresql.cnpg.io -n "$NS" -o jsonpath='{.items[*].spec.name}' 2>/dev/null || true)"
for db in temporal temporal_visibility litellm; do
  if [[ " $dbs " == *" $db "* ]]; then
    check_pass "database $db" "declared in CloudNativePG"
  else
    check_fail "database $db" "missing in $NS"
  fi
done

# --- Role login & isolation (in-cluster pod, Secret values never printed) ---

pod="pg-smoke-$$"
overrides="$(jq -cn --arg pod "$pod" --arg img "$PG_IMAGE" '{
  spec: {
    containers: [{
      name: $pod,
      image: $img,
      imagePullPolicy: "IfNotPresent",
      command: ["sh", "-c", "
        set -e
        PGPASSWORD=\"$TEMPORAL_PW\" psql -h ai-postgres-cluster-rw -U temporal -d temporal -c \"SELECT 1\" >/dev/null && echo ok:temporal:temporal
        PGPASSWORD=\"$TEMPORAL_PW\" psql -h ai-postgres-cluster-rw -U temporal -d temporal_visibility -c \"SELECT 1\" >/dev/null && echo ok:temporal:temporal_visibility
        if PGPASSWORD=\"$TEMPORAL_PW\" psql -h ai-postgres-cluster-rw -U temporal -d litellm -c \"SELECT 1\" >/dev/null 2>&1; then exit 1; else echo denied:temporal:litellm; fi
        PGPASSWORD=\"$LITELLM_PW\" psql -h ai-postgres-cluster-rw -U litellm -d litellm -c \"SELECT 1\" >/dev/null && echo ok:litellm:litellm
        if PGPASSWORD=\"$LITELLM_PW\" psql -h ai-postgres-cluster-rw -U litellm -d temporal -c \"SELECT 1\" >/dev/null 2>&1; then exit 1; else echo denied:litellm:temporal; fi
        if PGPASSWORD=\"$LITELLM_PW\" psql -h ai-postgres-cluster-rw -U litellm -d temporal_visibility -c \"SELECT 1\" >/dev/null 2>&1; then exit 1; else echo denied:litellm:temporal_visibility; fi
      "],
      env: [
        {name: "TEMPORAL_PW", valueFrom: {secretKeyRef: {name: "ai-postgres-temporal-credentials", key: "password"}}},
        {name: "LITELLM_PW",  valueFrom: {secretKeyRef: {name: "ai-postgres-litellm-credentials",  key: "password"}}}
      ]
    }]
  }
}')"

if out="$(kc run "$pod" --rm -i --restart=Never -n "$NS" --image="$PG_IMAGE" --overrides="$overrides" 2>/dev/null)" \
  && grep -q "denied:temporal:litellm" <<<"$out" \
  && grep -q "denied:litellm:temporal" <<<"$out"; then
  check_pass "role temporal" "connects to temporal & temporal_visibility; rejected from litellm"
  check_pass "role litellm" "connects to litellm; rejected from temporal & temporal_visibility"
else
  check_fail "role isolation" "psql check failed inside $NS"
fi

finish_checks
