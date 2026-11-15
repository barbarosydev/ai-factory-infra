---
name: debug-stack
description: Diagnose a failing ai-factory stack. Use when task doctor or task up fails, a pod is not ready, or LiteLLM, Temporal, Postgres or Ollama does not answer.
---

# Debug the stack

Work from evidence, read-only, until you can name the cause. Propose the fix; do not apply it without asking.

1. Run `task doctor -- --json` (before phase 6: `task doctor:prereqs -- --json`). Take the first FAIL; later failures are often caused by it.
2. Find the component's pods: `task kube -- get pods -n ai-platform -o wide`.
3. For a pod that is not ready, read in this order and stop when the cause is clear:
   - `task kube -- describe pod <pod> -n ai-platform` (events at the bottom: image pull, scheduling, probes)
   - `task kube -- logs <pod> -n ai-platform --all-containers --tail=200`
   - `task kube -- logs <pod> -n ai-platform --previous` when it restarted
   - `task kube -- get events -n ai-platform --sort-by=.lastTimestamp`
4. Known causes on this Mac:
   - Image pull errors: a proxy came back (`task doctor:prereqs` warns), or the macOS PAC proxy affects Docker.
   - LiteLLM cannot reach models: Ollama not running on the Mac, a model missing (`ollama list`), or the Ollama app kept a stale proxy (restart Ollama).
   - Temporal schema jobs hang: check the job logs; the chart runs with `useHelmHooks: false`.
   - Postgres: check the CloudNativePG `Cluster` status with `task kube -- get cluster -n ai-platform`.
5. Report: the failing check, the evidence (one or two log lines, never Secret values), the cause, and the fix as a Terraform change or a task command. Then run `task doctor` again after the fix is applied.

Never print Secret values, never use the global kubeconfig, never fix by hand with kubectl apply or helm.
