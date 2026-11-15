# Architecture

> Stub. Phase 6 completes this page with the measured memory use.

One command, `task up`, starts LiteLLM, Temporal and Ollama on the Mac. Terraform installs everything inside a k3d cluster; Ollama runs natively for the GPU.

```text
Mac
├── Ollama (native, port 11434)  gemma4:12b, gemma4:e4b
└── Docker Desktop
    └── k3d cluster "ai-factory" (k3s)
        ├── Traefik ingress :8080 → litellm.localhost, temporal.localhost
        └── namespace ai-platform (owned by Terraform)
            ├── PostgreSQL (CloudNativePG): temporal, temporal_visibility, litellm
            ├── LiteLLM → Service "ollama" → Ollama on the Mac
            └── Temporal (frontend also on :7233 for workers on the Mac)
```

LiteLLM never addresses the Mac directly: it calls the `ollama` Service. Moving the models elsewhere later means changing only that Service.
