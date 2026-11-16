# smoke tests

Each script prints one `PASS`, `WARN` or `FAIL` line per check (or JSON with `-- --json`), exits 0 only when nothing failed, and never reads or prints Secret values.

| Script | Task | What it checks |
| --- | --- | --- |
| `cluster.sh` | `task smoke:cluster` | Cluster running, project kubeconfig holds only `k3d-ai-factory`, node Ready, Traefik answers on 8080, a pod reaches Ollama on the Mac, your own kubeconfig unchanged. `-- --lifecycle` first runs `task down` and `task up` and checks the same cluster came back |
| `postgres.sh` | `task smoke:postgres` | CloudNativePG operator Ready, `ai-postgres-cluster` Ready, databases `temporal`, `temporal_visibility` and `litellm` present, and `psql` login isolation (`temporal` and `litellm` roles can log in to their own database(s) only) |
| `litellm.sh` | `task smoke:litellm` | `ollama` ExternalName Service, `litellm` Deployment Ready, Admin UI on `http://litellm.localhost:8080/ui`, real chat completions for `pm-agent`, `dev-agent` and `sec-agent` using each agent's virtual key, and cross-agent virtual key rejection |
| `temporal.sh` | `task smoke:temporal` | Temporal `frontend`, `history`, `matching`, `worker` and `web` Deployments Ready, schema and namespace Jobs Complete, `localhost:7233` gRPC `SERVING`, `default` namespace registered, a sample workflow started and completed from the Mac, and Web UI (`http://temporal.localhost:8080`) listing the completed workflow |

`task doctor` (`scripts/doctor.sh`) runs `doctor:prereqs` and all four smoke suites above in order.
