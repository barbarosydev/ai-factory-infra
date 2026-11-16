# ai-factory-infra

Personal async multi-agent software factory: the local platform it runs on.

LiteLLM, Temporal and Ollama on a Mac, with k3d, Terraform and Helm. See [docs/architecture.md](docs/architecture.md).

## Getting started

1. Set up the Mac: [docs/prerequisites.md](docs/prerequisites.md).
2. Check it, and turn on the checks before each commit:

```bash
task doctor:prereqs
```

```bash
pre-commit install
```

3. Start the stack (runs `task doctor` automatically at the end), check status/access, and stop it again when done (data is kept):

```bash
task up
```

```bash
task doctor
task status
task access
```

```bash
task down
```

`task --list` shows every command; [docs/runbook.md](docs/runbook.md) says when to use each.

## Docs

- [Prerequisites](docs/prerequisites.md)
- [Architecture](docs/architecture.md)
- [Runbook](docs/runbook.md)
- [Secrets](docs/secrets.md)
- [Claude Code harness](docs/harness.md)
- [Architecture decision records](docs/adr/README.md)
