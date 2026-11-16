# ADR-0008: Built-In Traefik Ingress on Port 8080

## Context

Developers need stable browser URLs for both the LiteLLM gateway/Admin UI and the Temporal Web UI without managing `/etc/hosts` entries or running `kubectl port-forward` in separate terminals.

## Decision

Keep k3s's built-in **Traefik** ingress controller enabled on host port `127.0.0.1:8080` and create standard Kubernetes `Ingress` resources (`ingressClassName: traefik`) for:
- `http://litellm.localhost:8080` (`svc/litellm:4000`)
- `http://temporal.localhost:8080` (`svc/temporal-web:8080`)

## Why

- RFC 6761 reserves `*.localhost` to resolve automatically to loopback (`127.0.0.1` / `::1`) on macOS and modern browsers with zero `/etc/hosts` edits.
- Host-header routing through Traefik multiplexes every HTTP UI and API over a single port (`8080`).

## Consequences

- `curl` commands when a corporate proxy is configured should pass `--noproxy '*'` so `*.localhost` traffic stays on loopback.
