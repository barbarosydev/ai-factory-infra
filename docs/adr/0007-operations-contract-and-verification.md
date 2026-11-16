# 0007. Operations contract and verification

## Status

Accepted

## Date

2026-11-16

## Context

People and agents run the same scripts many times and trust their result. A script that sleeps blindly, hides a failure or changes its output format makes every later check unreliable.

## Decision

- Every script follows one contract (also hard rule 7 in `AGENTS.md`):
  - Safe to repeat: running it again gives the same result.
  - Waits for a condition with a timeout, never a fixed sleep (`wait_until` in `scripts/lib/common.sh`).
  - Exit codes mean one thing: 0 means no real failure, non-zero means failure. A WARN never fails.
  - Checks print fixed `PASS`, `WARN` or `FAIL` lines, or JSON with `--json`, through the shared check functions.
- `task doctor` is the aggregate of the smoke suites (prerequisites, cluster, Postgres, LiteLLM, Temporal, state). `--only` runs a subset. It is the required health check after every change.
- `task doctor` also checks that Terraform state holds no secret values (suite `state`, counts and names only); a FAIL blocks the pull request.
- CI runs `task ci`: static checks, the Terraform module tests, the policies, the hook, script and Python tests, and gitleaks over the whole history.
- Only the Mac can verify the live stack. That includes the cluster, the databases and model completions, which need Ollama and the GPU.
- `task doctor` before a pull request is therefore a manual gate, enforced by the `ship-pr` skill and the `platform-verifier` agent.

## Consequences

- The result of any suite can be read by a person or parsed by an agent.
- Failures name the check and the detail.
- Procedures for failures are in the [runbook](../runbook.md).

### Known limitations

- CI never starts the stack, so a change that breaks only the live platform is caught on the Mac, not in Actions.
- The shared script library has no unit tests of its own yet.
