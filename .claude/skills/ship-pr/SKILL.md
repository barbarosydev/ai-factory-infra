---
name: ship-pr
description: End-to-end verification and pull-request shipping procedure. Use before committing, pushing or opening a PR to run the reviewer/verifier agents, confirm Terraform idempotence and task doctor health, and open a clean PR.
---

# Verify and ship a pull request

Follow these steps in order before committing or opening a pull request:

1. **Branch check**:
   - Run `git status -sb`. Confirm you are on a descriptive feature branch (never `main`) and no stray files exist.
2. **Terraform & Harness Review**:
   - If any file under `terraform/` changed, delegate a review to the `terraform-reviewer` agent and fix any findings.
3. **Gatekeeper Verification**:
   - Delegate to the `platform-verifier` agent (or run `task ci`, `task plan`, and `task doctor`) to verify:
     - `task ci` passes (`terraform fmt`, `validate`, lockfile, `tflint`, `terraform-docs`, `.yaml.tftpl` validation, `shellcheck`, hook & Python helper unit tests, `gitleaks`).
     - `task plan` reports `No changes. Your infrastructure matches the configuration.`
     - If cluster lifecycle or rollout-wait scripts (`scripts/up.sh`, `scripts/down.sh`, `scripts/cluster-*.sh`, `scripts/terraform.sh`, `cluster/`) changed, run `task smoke:cluster -- --lifecycle` in the main session to verify `task down` followed by `task up` on the live stack.
     - `task doctor` passes with `0 failed`; its `tfstate secrets` check is a blocking gate. Agents run the script and see only its count, never the state.
4. **Commit & Push**:
   - Stage intentional changes (`git add -A`), check `git status -sb` one last time, commit with a conventional commit message (`feat(...)`, `fix(...)`, `chore(...)`, `docs(...)`), and push (`git push -u origin <branch>`).
5. **Open or Update PR**:
   - Use `gh pr create --base main --head <branch>` with the `## Summary` and `## Verification` sections of `.github/pull_request_template.md`, recording the exact `task plan`, `task doctor`, and `task ci` results.
