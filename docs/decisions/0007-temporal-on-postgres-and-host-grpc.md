# ADR-0007: Temporal 1.8.0 on PostgreSQL with SQL Visibility and Host gRPC

## Context

The platform needs a durable workflow orchestrator whose Web UI is reachable in the browser and whose frontend gRPC server (`:7233`) is directly reachable from the Mac so workers and the `temporal` CLI can run outside the cluster during development.

## Decision

- Deploy the official Temporal Helm chart **`1.8.0`** (server `1.32.2`, Web UI `2.56.1`) from `https://go.temporal.io/helm-charts` in `terraform/modules/temporal` with 1 replica per service (`frontend`, `history`, `matching`, `worker`, `web`) and `admintools.enabled: false`.
- Use PostgreSQL (`postgres12` plugin) for both `default` (`temporal` DB) and `visibility` (`temporal_visibility` DB) datastores with `createDatabase: false`, `manageSchema: true`, and no Elasticsearch.
- Run schema setup and `default` namespace creation (`3d` retention) as standard Jobs (`useHelmHooks: false`).
- Set `server.frontend.service.type: LoadBalancer` so k3s ServiceLB binds port `7233` on the loadbalancer node (`127.0.0.1:7233:7233` in `cluster/k3d-config.yaml`).

## Why

- SQL visibility on PostgreSQL 16 eliminates Elasticsearch's multi-gigabyte JVM footprint: all 5 Temporal pods together use only **390 MiB** of RAM.
- Setting `useHelmHooks: false` avoids Helm hook deadlocks when `helm_release` runs under Terraform, while `scripts/terraform.sh` explicitly waits for the schema/namespace Jobs and Deployments.
- Exposing `temporal-frontend` via `LoadBalancer` makes `localhost:7233` work natively on the Mac without background `kubectl port-forward` processes.

## Consequences

- `task smoke:temporal` verifies cluster health on `localhost:7233`, starts and completes a real workflow from the Mac, and confirms it appears in the Temporal Web UI (`http://temporal.localhost:8080`).
