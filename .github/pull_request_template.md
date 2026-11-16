## Summary

<!-- What changed and why, in a few lines. Link the ADR when a decision changed. -->

## Verification

<!-- Paste the result lines. Skip the live-stack lines only for docs-only changes. -->

- [ ] `git status -sb` shows the intended branch
- [ ] `task ci`:
- [ ] `task apply`, then a second `task plan` shows no changes (if `terraform/`, `cluster/`, `scripts/` or `tests/` changed):
- [ ] `task doctor` fully green, including `tfstate secrets`:
- [ ] Docs or an ADR updated (if behaviour, a pin, a port or a command changed)
