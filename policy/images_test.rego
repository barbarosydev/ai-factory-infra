package images

zeros := "0000000000000000000000000000000000000000000000000000000000000000"

pinned_tag := concat("", ["1.2.3@sha256:", zeros])

test_pinned_variable_passes if {
	count(deny) == 0 with input as {"variable": {
		"app_image_tag": [{"default": pinned_tag, "type": "${string}"}],
		"namespace": [{"default": "ai-platform"}],
	}}
}

test_tag_only_variable_fails if {
	some msg in deny with input as {"variable": {"app_image_tag": [{"default": "1.2.3"}]}}
	contains(msg, "variable \"app_image_tag\"")
}

test_latest_variable_fails if {
	some msg in deny with input as {"variable": {"app_image_tag": [{"default": concat("", ["latest@sha256:", zeros])}]}}
	contains(msg, "app_image_tag")
}

test_variable_without_default_fails if {
	some msg in deny with input as {"variable": {"app_image_tag": [{"type": "${string}"}]}}
	contains(msg, "is missing")
}

test_pinned_k3d_image_passes if {
	count(deny) == 0 with input as {"kind": "Simple", "image": concat("", ["rancher/k3s:v1.0.0-k3s1@sha256:", zeros])}
}

test_k3d_tag_only_fails if {
	some msg in deny with input as {"kind": "Simple", "image": "rancher/k3s:v1.0.0-k3s1"}
	contains(msg, "k3d config image")
}

test_k3d_latest_fails if {
	some msg in deny with input as {"kind": "Simple", "image": "rancher/k3s:latest"}
	contains(msg, "k3d config image")
}

test_pinned_mcp_image_passes if {
	count(deny) == 0 with input as {"mcpServers": {"terraform": {
		"command": "docker",
		"args": ["run", "-i", "--rm", concat("", ["example/server:1.0.0@sha256:", zeros]), "--toolsets=registry"],
	}}}
}

test_mcp_tag_only_fails if {
	some msg in deny with input as {"mcpServers": {"terraform": {
		"command": "docker",
		"args": ["run", "-i", "--rm", "example/server:1.0.0"],
	}}}
	contains(msg, "MCP server \"terraform\"")
}

test_mcp_latest_fails if {
	some msg in deny with input as {"mcpServers": {"terraform": {
		"command": "docker",
		"args": ["run", "--rm", "example/server:latest"],
	}}}
	contains(msg, "`latest`")
}
