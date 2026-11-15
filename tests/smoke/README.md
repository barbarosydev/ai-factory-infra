# smoke tests

| Script | Task | What it checks |
| --- | --- | --- |
| `cluster.sh` | `task smoke:cluster` | Cluster running, project kubeconfig holds only `k3d-ai-factory`, node Ready, Traefik answers on 8080, a pod reaches Ollama on the Mac, your own kubeconfig unchanged. `-- --lifecycle` first runs `task down` and `task up` and checks the same cluster came back |

Phase 6 adds smoke tests for Postgres, LiteLLM and Temporal and folds them into `task doctor`.
