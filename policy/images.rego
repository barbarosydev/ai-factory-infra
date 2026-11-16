# Rule 4: every image is pinned by digest and none uses `latest`
# (hard rule 6).
#
# Input, one file at a time, recognised by its shape:
#   - terraform/environments/local/variables.tf (hcl2): every variable whose
#     name contains "image" has a default ending in @sha256:<64 hex>;
#   - cluster/k3d-config.yaml (yaml): the k3s node `image`;
#   - .mcp.json (json): each server started with `docker` passes an image
#     argument pinned by digest.
# An image pinned only by tag can change under the same name; a digest cannot.
#
# Not covered: PROBE_IMAGE in scripts/lib/common.sh (bash has no parser in
# Conftest), and images inside the Helm values templates (*.yaml.tftpl),
# which the module variables' validation blocks already check.
package images

digest_pattern := `@sha256:[0-9a-f]{64}$`

# "latest" as the whole tag: "app:latest", "latest@sha256:...", "latest".
latest_pattern := `(^|:)latest(@|$)`

pinned(ref) if {
	is_string(ref)
	regex.match(digest_pattern, ref)
	not regex.match(latest_pattern, ref)
}

# Terraform variables: input.variable.<name>[0].default
deny contains msg if {
	some name, blocks in input.variable
	contains(name, "image")
	some block in blocks
	not pinned(object.get(block, "default", null))
	msg := sprintf("variable \"%s\" default %v is not pinned: use <tag>@sha256:<64 hex>, never latest (hard rule 6, upgrade-version skill)", [name, object.get(block, "default", "is missing")])
}

# k3d config: top-level `image`.
deny contains msg if {
	input.kind == "Simple"
	not pinned(object.get(input, "image", null))
	msg := sprintf("k3d config image %v is not pinned: use rancher/k3s:<tag>@sha256:<64 hex>, never latest (hard rule 6, upgrade-version skill)", [object.get(input, "image", "is missing")])
}

# .mcp.json: docker servers need one digest-pinned argument.
deny contains msg if {
	some name, server in input.mcpServers
	server.command == "docker"
	count([arg | some arg in server.args; pinned(arg)]) == 0
	msg := sprintf("MCP server \"%s\" runs a docker image that is not pinned: use <image>:<tag>@sha256:<64 hex> in args (hard rule 6)", [name])
}

deny contains msg if {
	some name, server in input.mcpServers
	some arg in server.args
	regex.match(latest_pattern, arg)
	msg := sprintf("MCP server \"%s\" uses a `latest` image (%s); pin an exact tag and digest (hard rule 6)", [name, arg])
}
