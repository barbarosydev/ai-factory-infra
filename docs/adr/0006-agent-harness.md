# 0006. Agent harness

## Status

Accepted

## Date

2026-11-16

## Context

Coding agents (Claude Code and others) work directly on this repo, next to a Mac that holds real cloud credentials. Instructions in a text file depend on the model following them, so the important rules need enforcement that does not. [harness.md](../harness.md) describes each piece.

## Decision

- A rule that must hold for every agent tool lives in a tool-neutral layer: `AGENTS.md`, the scripts, Terraform validations, and `task ci` in pre-commit and CI. `.claude/` adds Claude Code layers on top.
- Each Claude Code layer has one job:
  - Rules: `AGENTS.md` is the tool-neutral source, `CLAUDE.md` imports it, and `.claude/rules/` holds conventions that load only for matching paths.
  - Permissions (`.claude/settings.json`): allow, ask and deny lists. Deny wins; anything unlisted asks.
  - Hooks: deterministic checks before or after a tool call, with tests in `tests/hooks/`. Used for rules that must hold every time.
  - Skills: procedures loaded when a task matches.
  - Agents: read-only helpers for jobs with long output, such as logs or reviews. A hook enforces read-only, because an agent's tool list cannot narrow Bash.
  - MCP: the Terraform registry server, because the provider 3.x docs are newer than most examples.
- The bar for adding a skill or agent: the same procedure has come up a third time, or the job produces output that would crowd the main conversation. One-line rules go in `CLAUDE.md`. Changing a hook requires changing its tests.
- There is no Kubernetes MCP server. `task kube` covers the need, and a second path to clusters is a risk on a Mac with AKS contexts.
- `branch-guard` blocks commits and pushes on main. An IDE once switched the checkout to main in the middle of a task, so the branch is checked when the command runs.

## Consequences

- Sessions may run in git worktrees. All of them share the one live stack, whose kubeconfig and state stay in the main checkout, and hooks judge the directory a command runs in.
- Hooks and deny rules apply to subagents too.
- `task ci` runs the hook tests, so a hook cannot silently stop working.

### Known limitations

- Pattern-matching hooks do not inspect a script the agent writes and then runs. The Claude Code Bash sandbox closes this and passed its trial (`tests/sandbox/`), but stays optional and off in shared settings because it covers one tool only. The deny rules, the project-only kubeconfig and the review roles cover the gap.
- In a desktop-app worktree session, settings and hooks come from the main checkout, so a harness change is live only after merge.
