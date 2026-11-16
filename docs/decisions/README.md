# Architecture Decision Records

Each record documents a key architectural decision from the AI Factory Infra master plan: **context**, **decision**, **why**, and **consequences**.

| ADR | Title | Area |
| --- | --- | --- |
| [ADR-0001](0001-docker-desktop-and-sizing.md) | Docker Desktop and Resource Sizing | Container runtime, CPU/RAM/swap ceilings |
| [ADR-0002](0002-k3d-cluster-and-isolated-kubeconfig.md) | k3d Cluster and Isolated Project Kubeconfig | k3d `5.9.0`, k3s `v1.37.2+k3s1`, `.kube/config` isolation |
| [ADR-0003](0003-terraform-and-local-state.md) | Terraform 1.17.2, Local State, and Namespace Ownership | Terraform modules, provider 3.x pins, `ai-platform` namespace |
| [ADR-0004](0004-native-ollama-and-gemma4-models.md) | Native Ollama on macOS and Gemma 4 Model Selection | Host GPU execution, `ollama` Service, `gemma4:12b` & `gemma4:e4b` |
| [ADR-0005](0005-cloudnativepg-shared-postgres.md) | CloudNativePG and Shared PostgreSQL with Isolated Databases | CloudNativePG, PostgreSQL 16, 3 databases, `pg_hba` isolation |
| [ADR-0006](0006-litellm-oci-chart-and-virtual-keys.md) | LiteLLM OCI Chart, Prompt Storage, and Per-Agent Virtual Keys | LiteLLM `1.109.1`, spend log prompts, scoped agent virtual keys |
| [ADR-0007](0007-temporal-on-postgres-and-host-grpc.md) | Temporal 1.8.0 on PostgreSQL with SQL Visibility and Host gRPC | Temporal `1.8.0` (`1.32.2`), SQL visibility, LoadBalancer `:7233` |
| [ADR-0008](0008-traefik-ingress-routing.md) | Built-In Traefik Ingress on Port 8080 | `litellm.localhost:8080` and `temporal.localhost:8080` |
| [ADR-0009](0009-four-layer-secret-management.md) | Four-Layer Secret Management and Write-Only Attributes | `ephemeral "random_password"`, `data_wo`, `gitleaks`, Claude hooks |
| [ADR-0010](0010-tooling-taskfile-and-ci-gates.md) | Open-Source Tooling, Thin Taskfile, and Pre-Commit CI Gates | `Brewfile`, `scripts/`, `task ci`, `pre-commit` & GitHub Actions |
