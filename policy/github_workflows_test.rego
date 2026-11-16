package github

test_read_only_workflow_passes if {
	count(deny) == 0 with input as {
		"name": "ci",
		"permissions": {"contents": "read"},
		"jobs": {"ci": {"runs-on": "ubuntu-24.04", "steps": []}},
	}
}

test_missing_permissions_fails if {
	some msg in deny with input as {"name": "ci", "jobs": {"ci": {}}}
	contains(msg, "contents: read")
}

test_top_level_write_fails if {
	deny["workflow grants `pull-requests: write` at top level; the token must stay read-only"] with input as {
		"permissions": {"contents": "read", "pull-requests": "write"},
		"jobs": {"ci": {}},
	}
}

test_write_all_fails if {
	some msg in deny with input as {"permissions": "write-all", "jobs": {"ci": {}}}
	contains(msg, "write-all")
}

test_job_level_write_fails if {
	deny["job \"release\" grants `contents: write`; the token must stay read-only"] with input as {
		"permissions": {"contents": "read"},
		"jobs": {"release": {"permissions": {"contents": "write"}}},
	}
}

test_action_pinned_by_sha_passes if {
	count(deny) == 0 with input as {
		"permissions": {"contents": "read"},
		"jobs": {"ci": {"steps": [
			{"uses": "actions/checkout@0000000000000000000000000000000000000000"},
			{"uses": "./.github/actions/local"},
			{"run": "task ci"},
		]}},
	}
}

test_action_pinned_by_tag_fails if {
	some msg in deny with input as {
		"permissions": {"contents": "read"},
		"jobs": {"ci": {"steps": [{"uses": "actions/checkout@v7.0.1"}]}},
	}
	contains(msg, "full commit SHA")
}
