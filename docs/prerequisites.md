# Prerequisites

Set up a Mac for ai-factory-infra in five steps, then run one check. The check is read-only and tells you exactly what is missing.

```bash
task doctor:prereqs
```

Every line prints `PASS`, `WARN` or `FAIL`. The command exits 0 only when nothing failed. Add `-- --json` for machine-readable output.

## 1. Desktop apps

| App | Why | Install |
| --- | --- | --- |
| [Docker Desktop](https://docs.docker.com/desktop/setup/install/mac-install/) | Runs the k3d cluster | Download from Docker |
| [Ollama](https://ollama.com/download) | Runs the models natively, so they can use the Mac's GPU | Download from Ollama |
| [Homebrew](https://brew.sh) | Installs the command line tools | See brew.sh |

## 2. Docker Desktop settings

Open Docker Desktop, Settings, Resources, and set:

| Setting | Value | Why |
| --- | --- | --- |
| CPU limit | 8 | Every pod can start in parallel; the rest stays with macOS and Ollama |
| Memory limit | 12 GB | More than twice the expected use of about 2.6 GiB measured (see `docs/architecture.md`) |
| Swap | 2 GB | Absorbs short spikes, such as Temporal's first schema setup |
| Disk usage limit | 511 GB (at least 100 GB) | A ceiling only; images and volumes take about 8 GB |

Then open Settings, Kubernetes, and make sure **Enable Kubernetes is off**. Docker Desktop's own cluster is a second cluster we do not use, and it costs about 2 GB of memory.

The values are ceilings, not reservations: Docker only uses what the pods need.

## 3. Command line tools

From the repo root:

```bash
brew bundle --no-upgrade
```

```bash
tfenv install
```

`brew bundle` installs everything in the [Brewfile](../Brewfile). `--no-upgrade` leaves tools you already have at their current version. `tfenv install` reads [.terraform-version](../.terraform-version) and installs that exact Terraform version; inside this repo tfenv then uses it automatically, without changing your global default.

| Tool | Pinned or minimum | Used for |
| --- | --- | --- |
| k3d | exactly 5.9.0 | Creating and stopping the local cluster |
| terraform | exactly the version in `.terraform-version` | Installing everything inside the cluster |
| kubectl, helm | kubectl 1.36+, helm 4.0+ | Talking to the cluster |
| task | 3.40+ | The `task` commands |
| tflint, shellcheck | | Linting |
| jq, yq | | Scripts |
| pre-commit, gitleaks | | Checks and secret scan before each commit |
| temporal, terraform-docs, k9s | optional | Doctor checks, module docs, a cluster UI |

## 4. Checks before each commit

Once per clone, from the repo root:

```bash
pre-commit install
```

Every commit then runs `task ci -- --staged`: lint, the tests and a gitleaks scan of the staged changes. `task doctor:prereqs` warns (`pre-commit-hook`) when this step was skipped.

## 5. Models

```bash
ollama pull gemma4:12b
```

```bash
ollama pull gemma4:e4b
```

`gemma4:12b` serves pm-agent (about 7.6 GB). `gemma4:e4b` serves dev-agent and sec-agent (about 9.5 GB). Avoid loading very large models (around 19 GB) while the cluster runs: on a 36 GB Mac they starve everything else.

## Proxy

The stack assumes no network proxy. The check warns when `HTTP_PROXY`, `HTTPS_PROXY` or `ALL_PROXY` is set in your shell, because image pulls inside the cluster and pod traffic to Ollama can then fail.

It also warns when the running Ollama server still carries proxy variables. Ollama keeps the environment it started with, so if it started while a proxy was set, `ollama pull` fails with `proxyconnect ... connection refused` even after the proxy is gone. Run `task stop:ollama`, then `task up` (or quit Ollama from its menu bar icon and open it again).

If you need a proxy again later, pass the proxy settings into k3d and add the cluster and host names to `NO_PROXY`.

Docker Desktop's own proxy setting ("system", following macOS) does not get in the way: the cluster pulls its images through it without any change. Checked on 15 Nov 2026.

## Registry access

If Docker Desktop is signed in to an organization, the organization can block images by registry or publisher; a blocked image fails with `image access restricted`. Signing out of Docker Desktop lifts those rules. `task doctor:prereqs` warns (`docker-signin`) while Docker Desktop holds a Docker Hub login; it reads only the server names of stored logins, never the credentials. While this Mac was signed in to a work organization, `curlimages/curl` was blocked, so the probe pods use the official `busybox` image, which is allowed almost everywhere.

## Ports

These ports must be free before the first `task up`: 8080 (web pages through the cluster's ingress), 7233 (Temporal for workers on the Mac), 4000 (LiteLLM) and 5432 (PostgreSQL). Once the cluster runs, the check accepts 8080 and 7233 as used by the `ai-factory` cluster.

## What the check does not touch

`task doctor:prereqs` only reads. It never changes Docker settings, installs tools, pulls models, or reads your kubeconfig. Your global kube context and any other clusters in it stay out of reach.
