# Architecture

One command, `task up`, starts Ollama on the Mac, creates or resumes the local `k3d` Kubernetes cluster (`ai-factory`), applies the Terraform platform stack (`ai-platform`), and runs `task doctor` to verify every component end-to-end.

```mermaid
flowchart LR
  subgraph mac["Mac (Apple Silicon, 36 GB RAM)"]
    ollama["Ollama (native, :11434)<br/>gemma4:12b, gemma4:e4b"]
    worker["Temporal CLI & SDK workers<br/>(Mac host)"]
    browser["Browser / curl"]
    subgraph docker["Docker Desktop (8 CPUs, 12 GB RAM, 2 GB swap)"]
      subgraph k3d["k3d cluster ai-factory (k3s v1.37.2+k3s1)"]
        traefik["Traefik Ingress :8080"]
        svclb["k3s ServiceLB :7233"]
        subgraph ns["namespace ai-platform (Terraform)"]
          litellm["LiteLLM Gateway & Admin UI<br/>(1.109.1)"]
          temporal["Temporal Server & Web UI<br/>(chart 1.8.0, server 1.32.2, UI 2.56.1)"]
          phoenix["Arize Phoenix UI & OTLP<br/>(version-22.0.1, ELv2)"]
          svc["Service ollama<br/>(ExternalName -> host.k3d.internal)"]
          pg[("PostgreSQL 18 (CloudNativePG)<br/>DBs: temporal, temporal_visibility, litellm, phoenix")]
        end
      end
    end
  end
  browser -->|"http://litellm.localhost:8080"| traefik
  browser -->|"http://temporal.localhost:8080"| traefik
  browser -->|"http://phoenix.localhost:8080"| traefik
  worker -.->|"OTLP HTTP /v1/traces"| traefik
  traefik --> litellm
  traefik --> temporal
  traefik --> phoenix
  worker -->|"gRPC localhost:7233"| svclb
  svclb --> temporal
  litellm --> svc
  svc -->|"host.k3d.internal:11434"| ollama
  litellm -->|"user: litellm"| pg
  temporal -->|"user: temporal"| pg
  phoenix -->|"user: phoenix"| pg
```

## Components and responsibilities

| Component | Where it runs | Pinned version | Role in the platform |
| --- | --- | --- | --- |
| **Ollama** | Native on macOS (`127.0.0.1:11434`) | `>= 0.40` (`0.40.16`) | Serves `gemma4:12b` and `gemma4:e4b` directly on Apple Silicon GPU/Metal (Docker containers on macOS cannot access the GPU). |
| **k3d / k3s** | Docker Desktop (`ai-factory`) | k3d `5.9.0`, k3s `v1.37.2+k3s1` | Certified single-server Kubernetes cluster that starts and stops in seconds while keeping persistent volumes intact. |
| **Traefik** | `kube-system` (`:8080`) | Bundled with k3s | Routes `http://litellm.localhost:8080`, `http://temporal.localhost:8080`, and `http://phoenix.localhost:8080` over a single host port without `kubectl port-forward`. |
| **CloudNativePG & PostgreSQL** | `ai-platform` (`terraform/modules/postgres`) | Operator chart `0.29.1`, Cluster chart `0.9.0`, PostgreSQL `18` | Runs one shared PostgreSQL instance (`ai-postgres-cluster`) with four isolated databases (`temporal`, `temporal_visibility`, `litellm`, `phoenix`) and strict `pg_hba` per-role isolation (`temporal`, `litellm`, and `phoenix` users). |
| **Model Backend Service** | `ai-platform` (`terraform/modules/model-backend`) | Kubernetes `Service/v1` | `ExternalName` Service named `ollama` pointing at `host.k3d.internal:11434`. Decouples LiteLLM from where the model server runs. |
| **LiteLLM** | `ai-platform` (`terraform/modules/litellm`) | Chart & image `1.109.1` | OpenAI-compatible model gateway and Admin UI (`/ui`). Maps `pm-agent` -> `gemma4:12b` and `dev-agent` / `test-agent` / `sec-agent` -> `gemma4:e4b`, with one scoped virtual API key per agent. |
| **Temporal** | `ai-platform` (`terraform/modules/temporal`) | Chart `1.8.0` (server `1.32.2`, UI `2.56.1`) | Durable workflow orchestrator (`frontend`, `history`, `matching`, `worker`, `web`) backed by PostgreSQL persistence and SQL visibility. Exposes gRPC on `localhost:7233` to the Mac and the Web UI on `http://temporal.localhost:8080`. |
| **Arize Phoenix** | `ai-platform` (`terraform/modules/observability`) | Image `version-22.0.1` (Elastic License 2.0) | Self-hosted OpenTelemetry / OpenInference trace store and UI (`http://phoenix.localhost:8080`, `POST /v1/traces`) backed by the isolated `phoenix` PostgreSQL database with 7-day trace retention and loopback-only no-auth. |
| **Network Policies** | `ai-platform` (`terraform/modules/network-policies`) | 9 `NetworkPolicy` resources | `default-deny-all` + least-privilege ingress/egress across Traefik, CloudNativePG, LiteLLM, Temporal, Phoenix (Postgres-only egress), Jobs, and smoke probes ([ADR 0009](adr/0009-kubernetes-network-policies-and-zero-trust.md)). |

## Network and port map

| Host / In-cluster address | Protocol | Target | Purpose |
| --- | --- | --- | --- |
| `http://litellm.localhost:8080/v1` | HTTP | Traefik -> `svc/litellm:4000` | OpenAI-compatible chat completions API for agents |
| `http://litellm.localhost:8080/ui` | HTTP | Traefik -> `svc/litellm:4000` | LiteLLM Admin UI (`/ui/usage/`, `/ui/logs/`) |
| `http://temporal.localhost:8080` | HTTP | Traefik -> `svc/temporal-web:8080` | Temporal Web UI (workflows in `default` namespace) |
| `http://phoenix.localhost:8080` | HTTP | Traefik -> `svc/phoenix:6006` | Arize Phoenix trace UI and OTLP HTTP/protobuf receiver (`/v1/traces`) |
| `localhost:7233` | gRPC (h2c) | k3s ServiceLB -> `svc/temporal-frontend:7233` | Temporal frontend gRPC for the `temporal` CLI and SDK workers on the Mac |
| `http://127.0.0.1:11434` | HTTP | Native macOS Ollama process | Host Ollama API (`host.k3d.internal:11434` from inside pods) |
| `ai-postgres-cluster-rw.ai-platform.svc:5432` | TCP (PostgreSQL) | Primary PostgreSQL pod | In-cluster read-write database endpoint for LiteLLM, Temporal, and Arize Phoenix |

## Measured memory and CPU use

Measured with `task status` (`docker stats --no-stream`, `kubectl top pods -n ai-platform`, and `ollama ps`) on the 36 GB Mac while the full stack was running and serving requests:

### 1. In-cluster pods (`namespace: ai-platform`)

| Pod / Component | Idle CPU | Measured Memory (RSS) | Memory request / limit | Notes |
| --- | --- | --- | --- | --- |
| `litellm` | `19m` | **699 MiB** | 512Mi / 2Gi | Python proxy + Prisma client + Admin UI |
| `phoenix` | `12m` | **448 MiB** | 256Mi / 1Gi | Arize Phoenix OTLP HTTP/protobuf receiver + UI |
| `temporal-history` | `24m` | **188 MiB** | 192Mi / 512Mi | 512 history shards on PostgreSQL |
| `temporal-matching` | `9m` | **63 MiB** | 64Mi / 128Mi | Task queue matching engine |
| `temporal-frontend` | `8m` | **56 MiB** | 64Mi / 256Mi | gRPC (`:7233`) & HTTP (`:7243`) frontend |
| `temporal-worker` | `6m` | **51 MiB** | 64Mi / 128Mi | Internal system workflows |
| `temporal-web` | `1m` | **32 MiB** | 32Mi / 128Mi | Web UI (`temporalio/ui:2.56.1`) |
| *Temporal subtotal (5 pods)* | *`48m`* | ***390 MiB*** | *416Mi / 1.125Gi* | SQL visibility avoids Elasticsearch overhead |
| `ai-postgres-cluster-1` | `10m` | **231 MiB** | 256Mi / 1Gi | PostgreSQL 18 (`max_connections = 150`, `shared_buffers = 256MB`) |
| `cnpg-cloudnative-pg` | `2m` | **36 MiB** | 64Mi / 128Mi | CloudNativePG operator |
| *PostgreSQL subtotal (2 pods)* | *`12m`* | ***267 MiB*** | *320Mi / 1.125Gi* | Shared server across 4 isolated databases |

Requests and limits are set in the Terraform values templates and manifests: memory limits are about twice the measured RSS, rounded up to a power-of-two step (history gets 512Mi for its 512-shard cache), and CPU requests stay modest (10m to 200m).

### 2. Whole-Mac memory budget (36 GB total)

| Consumer | Measured Memory | Ceiling / Budget | Detail |
| --- | --- | --- | --- |
| **k3d cluster (`k3d-ai-factory-server-0` + `serverlb`)** | **3.05 GiB** (`26.3%` of limit) | 12.0 GiB Docker Desktop ceiling | Includes k3s control plane, containerd, CoreDNS, Traefik, ServiceLB, PostgreSQL (`267 MiB`), LiteLLM (`699 MiB`), Arize Phoenix (`448 MiB`), and Temporal (`390 MiB`). |
| **Ollama (idle, no models loaded)** | **~0.1 GiB** | — | Models unload automatically on `task down` or after idle timeout. |
| **Ollama (`gemma4:12b` loaded)** | **~8.9 GiB** | — | Used by `pm-agent`. |
| **Ollama (`gemma4:e4b` loaded)** | **~9.8 GiB** | — | Used by `dev-agent`, `test-agent` and `sec-agent` (9.5 GB on disk). |
| **macOS, browser, IDE, Claude Code** | **~10.0 GiB** | — | Host OS and developer tools. |
| **Free headroom** | **~14.5 GiB** (1 model) / **~4.7 GiB** (both models) | — | Comfortable margin without swap pressure. |
