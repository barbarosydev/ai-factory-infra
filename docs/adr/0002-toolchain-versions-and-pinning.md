# 0002. Toolchain, versions and pinning

## Status

Accepted

## Date

2026-11-16

## Context

The repo must rebuild from a fresh clone and give the same results on the Mac and in GitHub Actions. It is private and has one user, so it should add as little process as possible.

## Decision

- Open source first. There are two approved exceptions, both approved by the repo owner: Docker Desktop, because it is already installed and configured on the Mac, and Terraform, because it is the owner's chosen infrastructure tool.
- Terraform with local, gitignored state. Modules live in `terraform/modules/`, one thin environment in `terraform/environments/local`, and Terraform owns the `ai-platform` namespace. Kubernetes and Helm providers use 3.x syntax. A cloud environment would be a new folder that calls the same modules.
- The Taskfile is thin: each task calls one script in `scripts/`, so shellcheck can lint it and it can be run alone.
- "Pinned exactly" means:
  - Tools: an exact version in the toolchain files and in CI.
  - Helm charts: an exact `version` in the Terraform module.
  - Container images: tag plus multi-arch index digest; for in-cluster images the pin lives once in Terraform, and probe pods reuse the image the cluster runs.
  - Providers: exact version through `.terraform.lock.hcl`, with hashes for the Mac and both Linux platforms.
  - GitHub Actions: a full commit SHA.
  The values live in `terraform/environments/local/variables.tf`, `cluster/k3d-config.yaml`, `.mcp.json` and `.github/workflows/ci.yml`; this record states the rule, not the numbers.
- Upgrades go through the `upgrade-version` skill, by hand. Renovate is not used while the repo is private and single-user, because it adds an app, a config and a PR stream.
- One `task ci` runs lint, hook tests and gitleaks. pre-commit and GitHub Actions both call it, so they cannot drift apart.
- Tool boundaries: tflint lints Terraform; `terraform test` (planned) checks module behaviour; Conftest (planned) checks repo-wide conventions across file types. A rule goes to the first tool that fits.

## Consequences

- A fresh clone needs the tools, `task up` and nothing else.
- Every container image is pinned by tag and digest, and Terraform validation rejects an image pin without a digest. Some other pins are not yet exact everywhere (Actions pinned by tag, tools checked against minimum versions). Closing these gaps is planned.
- An image bump changes the tag and the digest together, so pods restart even when the content is unchanged.
- Local state is simple but lives on one machine.
