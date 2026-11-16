# ADR-0001: Docker Desktop and Resource Sizing

## Context

The local AI Factory platform runs Kubernetes (k3d/k3s), PostgreSQL, LiteLLM, and Temporal in containers on a 36 GB Apple Silicon Mac alongside native macOS apps and Ollama.

## Decision

Use **Docker Desktop** (`>= 29.0`) configured with **8 CPUs, 12 GB memory, 2 GB swap, and a 511 GB disk ceiling**, with Docker Desktop's built-in Kubernetes **disabled**.

## Why

- Docker Desktop is already installed and configured on the Mac, and is an approved exception to the open-source-first rule.
- 12 GB is a ceiling, not a reservation: measured in-cluster usage is **2.63 GiB** (`22.5%` of the ceiling), leaving plenty of headroom for restarts, schema migrations, and loading both Ollama models (~9–10 GB each) on the 36 GB host.
- Turning off Docker Desktop's built-in Kubernetes saves ~2 GB of idle memory and avoids a second competing local cluster.

## Consequences

- `task doctor:prereqs` verifies CPU, memory, swap, disk, and that Docker Desktop's built-in Kubernetes is off before `task up` proceeds.
- Being signed in to a corporate Docker Hub organization can trigger registry access restrictions (`image access restricted`); `task doctor:prereqs` warns on `docker-signin`.
