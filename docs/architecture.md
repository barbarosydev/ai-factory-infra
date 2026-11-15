# Architecture

> Stub. Phase 6 completes this page with the measured memory use.

One command, `task up`, starts LiteLLM, Temporal and Ollama on the Mac. Terraform installs everything inside a k3d cluster; Ollama runs natively for the GPU.

```mermaid
flowchart LR
  subgraph mac["Mac"]
    ollama["Ollama (native, :11434)<br/>gemma4:12b, gemma4:e4b"]
    worker["Temporal workers<br/>(later)"]
    browser["Browser"]
    subgraph docker["Docker Desktop"]
      subgraph k3d["k3d cluster ai-factory (k3s)"]
        traefik["Traefik ingress :8080"]
        subgraph ns["namespace ai-platform (Terraform)"]
          litellm["LiteLLM"]
          temporal["Temporal"]
          svc["Service ollama"]
          pg[("PostgreSQL (CloudNativePG)<br/>temporal, temporal_visibility, litellm")]
        end
      end
    end
  end
  browser -->|litellm.localhost:8080| traefik
  browser -->|temporal.localhost:8080| traefik
  traefik --> litellm
  traefik --> temporal
  worker -->|:7233| temporal
  litellm --> svc
  svc -->|host network| ollama
  litellm --> pg
  temporal --> pg
```

LiteLLM never addresses the Mac directly: it calls the `ollama` Service. Moving the models elsewhere later means changing only that Service.
