package terraform.helm

good_release := {
	"chart": "app",
	"cleanup_on_fail": true,
	"max_history": 5,
	"timeout": 600,
	"version": "${var.chart_version}",
	"wait": true,
}

test_contract_release_passes if {
	count(deny) == 0 with input as {"resource": {"helm_release": {"app": [good_release]}}}
}

test_missing_version_fails if {
	deny["helm_release.app does not set `version`; pin the chart version exactly (hard rule 6)"] with input as {"resource": {"helm_release": {"app": [object.remove(good_release, ["version"])]}}}
}

test_wrong_max_history_fails if {
	some msg in deny with input as {"resource": {"helm_release": {"app": [object.union(good_release, {"max_history": 10})]}}}
	contains(msg, "`max_history = 5`")
}

test_missing_cleanup_on_fail_fails if {
	some msg in deny with input as {"resource": {"helm_release": {"app": [object.remove(good_release, ["cleanup_on_fail"])]}}}
	contains(msg, "`cleanup_on_fail = true`")
}

test_wait_false_fails if {
	some msg in deny with input as {"resource": {"helm_release": {"app": [object.union(good_release, {"wait": false})]}}}
	contains(msg, "`wait = true`")
}

test_missing_timeout_fails if {
	some msg in deny with input as {"resource": {"helm_release": {"app": [object.remove(good_release, ["timeout"])]}}}
	contains(msg, "`timeout`")
}
