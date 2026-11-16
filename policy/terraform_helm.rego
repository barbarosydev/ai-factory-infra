# Rule 2: every Helm release follows the module contract (hard rule 6 and
# .claude/rules/terraform.md).
#
# Input: every Terraform file (*.tf), parsed by Conftest's hcl2 parser.
#
# Each helm_release must:
#   - pin the chart with `version` (hard rule 6: pin every version exactly);
#   - set `cleanup_on_fail = true` and `max_history = 5`;
#   - set `wait = true` and an explicit `timeout` in seconds, so `task apply`
#     only finishes once the release is ready and fails instead of hanging.
# The modules use different timeouts (300 to 900 s), so only presence is
# checked, not the value. Whether `version` holds an exact version is left to
# the variable's validation block; here it must at least be set.
package terraform.helm

expected := {"cleanup_on_fail": true, "max_history": 5, "wait": true}

deny contains msg if {
	some name, blocks in input.resource.helm_release
	some block in blocks
	not block.version
	msg := sprintf("helm_release.%s does not set `version`; pin the chart version exactly (hard rule 6)", [name])
}

deny contains msg if {
	some name, blocks in input.resource.helm_release
	some block in blocks
	some attr, want in expected
	object.get(block, attr, null) != want
	msg := sprintf("helm_release.%s must set `%s = %v` (found %v); see .claude/rules/terraform.md", [name, attr, want, object.get(block, attr, "nothing")])
}

deny contains msg if {
	some name, blocks in input.resource.helm_release
	some block in blocks
	not is_number(object.get(block, "timeout", null))
	msg := sprintf("helm_release.%s must set an explicit `timeout` in seconds, as the other releases do", [name])
}
