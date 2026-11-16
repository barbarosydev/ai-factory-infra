package terraform.secrets

good_secret := {"resource": {"kubernetes_secret_v1": {"app": [{
	"data_wo": {"password": "${ephemeral.random_password.app.result}"},
	"data_wo_revision": "${var.password_version}",
	"metadata": [{"name": "app"}],
}]}}}

test_write_only_secret_passes if {
	count(deny) == 0 with input as good_secret
}

test_ephemeral_password_passes if {
	count(deny) == 0 with input as {"ephemeral": {"random_password": {"app": [{"length": 32}]}}}
}

test_readable_data_fails if {
	deny["kubernetes_secret_v1.app sets `data`, which stores the value in Terraform state; use `data_wo` and `data_wo_revision` instead (docs/secrets.md)"] with input as {"resource": {"kubernetes_secret_v1": {"app": [{
		"data": {"password": "${var.x}"},
		"data_wo_revision": 1,
	}]}}}
}

test_string_data_fails if {
	some msg in deny with input as {"resource": {"kubernetes_secret_v1": {"app": [{
		"data_wo": {"a": "b"},
		"data_wo_revision": 1,
		"string_data": {"a": "b"},
	}]}}}
	contains(msg, "`string_data`")
}

test_missing_revision_fails if {
	deny["kubernetes_secret_v1.app does not set `data_wo_revision`; write-only Secrets need both `data_wo` and `data_wo_revision` (docs/secrets.md)"] with input as {"resource": {"kubernetes_secret_v1": {"app": [{"data_wo": {"a": "b"}}]}}}
}

test_resource_random_password_fails if {
	some msg in deny with input as {"resource": {"random_password": {"app": [{"length": 32}]}}}
	contains(msg, "ephemeral")
}
