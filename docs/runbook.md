# Runbook

> Stub. Phases 2 to 6 fill in each command as it lands.

| Situation | Command |
| --- | --- |
| Check the Mac | `task doctor:prereqs` |
| Lint and secret scan | `task ci` |
| Look at the cluster | `task kube -- get pods -A` |
| Start everything | `task up` (phase 2+) |
| Stop, keep data | `task down` (phase 2+) |
| Health check | `task doctor` (phase 6) |
| Start from scratch | `task clean` then `task up` (phase 2+) |

## A secret leaked

1. Revoke and rotate it first, at its source. A secret that reached a commit counts as public, even if the commit was never pushed.
2. Then remove it from git history and force-push, and tell anyone who cloned the repo.
3. Find out how it got past pre-commit, the hooks and CI, and close that gap.
