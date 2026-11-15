# cluster

`k3d-config.yaml` defines the local cluster `ai-factory`: one k3s server on a pinned image, the API server on 127.0.0.1 only, and ports 8080 (Traefik ingress) and 7233 (Temporal gRPC) on 127.0.0.1.

Do not run `k3d cluster create` by hand. `task up` runs `scripts/cluster-setup.sh`, which also writes the project kubeconfig `.kube/config`, waits for readiness, and checks that your own kubeconfig stayed unchanged. See [docs/runbook.md](../docs/runbook.md#cluster-lifecycle).

The k3s version is the newest stable release within one minor of kubectl 1.37: `v1.37.2+k3s1`, the k3s stable channel on 15 Nov 2026. Bump it with the upgrade-version skill, which updates the tag and the digest together.
