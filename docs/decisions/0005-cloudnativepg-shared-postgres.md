# ADR-0005: CloudNativePG and Shared PostgreSQL with Isolated Databases

## Context

Temporal Helm chart `1.8.0` no longer bundles an in-chart PostgreSQL subchart, and Bitnami retired its free unauthenticated container images in 2025. Both Temporal and LiteLLM require PostgreSQL persistence.

## Decision

Deploy the **CloudNativePG** operator (`0.29.1`, app `1.30.1`) and a single **PostgreSQL `16`** cluster (`cluster` chart `0.9.0`, `ai-postgres-cluster`) in `terraform/modules/postgres` hosting three databases (`temporal`, `temporal_visibility`, `litellm`) and two least-privilege roles (`temporal`, `litellm`) enforced by custom `pg_hba` rules.

## Why

- CloudNativePG is the CNCF standard for Kubernetes PostgreSQL and runs identically on k3d and AKS.
- One PostgreSQL instance consumes only **186 MiB** total (`150 MiB` server + `36 MiB` operator) instead of running separate database servers per service.
- Separate databases (`temporal`, `temporal_visibility`, `litellm`) paired with `host ... 0.0.0.0/0 scram-sha-256` and `reject` rules in `pg_hba` guarantee that `litellm` cannot connect to Temporal's databases and `temporal` cannot connect to `litellm`.

## Consequences

- `task smoke:postgres` verifies both positive logins and negative cross-database rejection for `temporal` and `litellm`.
- Because `temporal` is a non-superuser role owning pre-created databases, the Temporal chart sets `createDatabase: false`.
