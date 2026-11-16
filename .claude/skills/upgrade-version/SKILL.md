---
name: upgrade-version
description: Upgrade a pinned version (Terraform, a provider, a Helm chart, k3d, the k3s image, an image or a tool). Use when asked to upgrade, bump or check for newer releases.
---

# Upgrade a pinned version

Every version in this repo is pinned exactly. An upgrade is a deliberate, checked change.

1. Find where it is pinned: `grep -rn "<old version>" --exclude-dir=.terraform .` (component chart versions and all in-cluster image pins (`tag@sha256:digest`) are centralized in `terraform/environments/local/variables.tf`, some chart versions with matching defaults in `terraform/modules/*/variables.tf`; probe pods reuse the image the cluster runs, so only `PROBE_IMAGE` (busybox) lives in `scripts/lib/common.sh`; other places include `.terraform-version`, `versions.tf`, `cluster/k3d-config.yaml`, `scripts/doctor-prereqs.sh`, `Brewfile` comments, `.mcp.json` (tag and digest), `.github/workflows/ci.yml`, `docs/`). You can delegate a full audit to the `version-security-auditor` agent.
2. Find the newest stable release from the official source (GitHub releases, the Terraform registry through the Terraform MCP server, the chart's index). Skip pre-releases.
3. Check compatibility before choosing:
   - k3s image: within one minor version of the local kubectl; prefer the k3s stable channel (`https://update.k3s.io/v1-release/channels`).
   - Images pinned as `tag@sha256:digest` (every in-cluster image, the k3s image, busybox and the MCP server): update the tag and digest together in the same edit, never one alone. Resolve the digest of the exact tag with `docker buildx imagetools inspect <image>:<tag> --format '{{json .Manifest}}' | jq -r .digest` and use that multi-arch index digest (media type `...image.index...`), not a per-platform manifest digest. If a Docker Desktop organization sign-in refuses the image, stop and report it; never guess a digest.
   - Versions that must move together (Terraform validation enforces them): `litellm_image_tag` and `litellm_chart_version`; `temporal_admin_tools_image_tag` and `temporal_server_image_tag`; the major in `postgres_image_name` and `postgres_version`. `cnpg_operator_image_tag` is the operator chart's `appVersion`.
   - After apply, check every pod image still carries a digest: `task kube -- get pods -n ai-platform -o jsonpath='{range .items[*]}{.spec.initContainers[*].image} {.spec.containers[*].image}{"\n"}{end}' | grep -v '@sha256:'` prints nothing.
   - PostgreSQL: a major version the Temporal server version supports.
   - Charts: read the release notes for breaking value changes between the two versions.
   - Providers: read the upgrade guide for a major bump.
4. Bump every place found in step 1 in one change. For providers, run `terraform -chdir=terraform/environments/local init -upgrade` and then `terraform -chdir=terraform/environments/local providers lock -platform=darwin_arm64 -platform=linux_amd64 -platform=linux_arm64` so the lock file works on both macOS and Linux CI.
5. For the k3s image, run `task clean` then `task up` and `task smoke:cluster` (asks first: data is lost). Otherwise run `task lint`, then `task plan` and show the diff. Ask before `task apply`.
6. After apply, run `task doctor`. Record the new version and date in the matching docs table.
