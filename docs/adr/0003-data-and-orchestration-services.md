# 0003. Data and orchestration services

## Status

Accepted

## Date

2026-11-16

## Context

Temporal and LiteLLM both need PostgreSQL. The Temporal chart no longer bundles a database, and running a separate server per service would waste memory on a single Mac.

## Decision

- One CloudNativePG server (operator plus cluster) holds three databases: `temporal`, `temporal_visibility` and `litellm`. CloudNativePG is the standard Kubernetes PostgreSQL operator and behaves the same on k3d and in the cloud.
- Two login roles, `temporal` and `litellm`. Custom `pg_hba` rules let each role reach only its own databases and reject the rest.
- Terraform generates the database passwords as ephemeral write-only values, so they never reach state. CloudNativePG does not generate them.
- Temporal runs on PostgreSQL for both the default and the visibility store (SQL visibility, no Elasticsearch), with one replica per service.
- Schema setup and namespace creation are plain Jobs, not Helm hooks, which can deadlock under `helm_release`. `scripts/terraform.sh` waits for them.
- `createDatabase: false` on both Temporal datastores. The databases are pre-created and owned by the non-superuser `temporal` role, and strict `pg_hba` means the SQL setup tool must not connect to the admin database.
- The Temporal frontend is a `LoadBalancer` Service on 7233. k3s ServiceLB and a k3d port mapping make it reachable from workers and the `temporal` CLI on the Mac.

## Consequences

- `task smoke:postgres` proves both the allowed logins and the cross-database rejections.
- `task smoke:temporal` runs a real workflow from the Mac.
- Password rotation is described in the `rotate-secrets` skill.

### Known limitations

- Temporal has no authentication and no TLS. This is acceptable only because the port is bound to loopback.
- Raw gRPC calls to `localhost:7233` need a `grpc-timeout` header.
