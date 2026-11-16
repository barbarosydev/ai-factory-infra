# 0006. Agent harness

## Status

Accepted

## Date

2026-11-16

## Context

Claude Code works directly on this repo, next to a Mac that holds real cloud credentials. Instructions in a text file depend on the model following them, so the important rules need enforcement that does not. [harness.md](../harness.md) describes each piece.

## Decision

- Each layer has one job:
  - Rules (`CLAUDE.md`): what a new teammate needs, loaded every session. Behaviour only.
  - Permissions (`.claude/settings.json`): allow, ask and deny lists. Deny wins; anything unlisted asks.
  - Hooks: deterministic checks before or after a tool call, with tests in `tests/hooks/`. Used for rules that must hold every time.
  - Skills: procedures loaded when a task matches.
  - Agents: read-only helpers for jobs with long output, such as logs or reviews.
  - MCP: the Terraform registry server, because the provider 3.x docs are newer than most examples.
- The bar for adding a skill or agent: the same procedure has come up a third time, or the job produces output that would crowd the main conversation. One-line rules go in `CLAUDE.md`. Changing a hook requires changing its tests.
- There is no Kubernetes MCP server. `task kube` covers the need, and a second path to clusters is a risk on a Mac with AKS contexts.
- `branch-guard` blocks commits and pushes on main. An IDE once switched the checkout to main in the middle of a task, so the branch is checked when the command runs.

## Consequences

- Hooks and deny rules apply to subagents too.
- `task ci` runs the hook tests, so a hook cannot silently stop working.

### Known limitations

- Pattern-matching hooks do not inspect a script the agent writes and then runs. Today the deny rules, the project-only kubeconfig and the review agents cover that gap.
- Agents are read-only by instruction, not by a restricted tool list.
