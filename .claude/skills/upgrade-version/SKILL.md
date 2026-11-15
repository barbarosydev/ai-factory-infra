---
name: upgrade-version
description: Upgrade a pinned version (Terraform, a provider, a Helm chart, k3d, the k3s image, an image or a tool). Use when asked to upgrade, bump or check for newer releases.
---

# Upgrade a pinned version

Every version in this repo is pinned exactly. An upgrade is a deliberate, checked change.

1. Find where it is pinned: `grep -rn "<old version>" --exclude-dir=.terraform .` (component chart and image versions are centralized in `terraform/environments/local/variables.tf` with matching defaults in `terraform/modules/*/variables.tf` and probe images in `scripts/lib/common.sh`; other places include `.terraform-version`, `versions.tf`, `cluster/k3d-config.yaml`, `scripts/doctor-prereqs.sh`, `Brewfile` comments, `.mcp.json` (tag and digest), `.github/workflows/ci.yml`, `docs/`). You can delegate a full audit to the `version-security-auditor` agent.
2. Find the newest stable release from the official source (GitHub releases, the Terraform registry through the Terraform MCP server, the chart's index). Skip pre-releases.
3. Check compatibility before choosing:
   - k3s image: within one minor version of the local kubectl; prefer the k3s stable channel (`https://update.k3s.io/v1-release/channels`).
   - Images pinned as `tag@sha256:digest`: update both together (`docker buildx imagetools inspect <image>:<tag>` prints the digest).
   - PostgreSQL: a major version the Temporal server version supports.
   - Charts: read the release notes for breaking value changes between the two versions.
   - Providers: read the upgrade guide for a major bump.
4. Bump every place found in step 1 in one change. For providers, run `terraform -chdir=terraform/environments/local init -upgrade` and then `terraform -chdir=terraform/environments/local providers lock -platform=darwin_arm64 -platform=linux_amd64 -platform=linux_arm64` so the lock file works on both macOS and Linux CI.
5. For the k3s image, run `task clean` then `task up` and `task smoke:cluster` (asks first: data is lost). Otherwise run `task lint`, then `task plan` and show the diff. Ask before `task apply`.
6. After apply, run `task doctor`. Record the new version and date in the matching docs table.
