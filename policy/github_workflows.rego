# Rule 6: GitHub workflows run with a read-only token (hard rule 5: no
# secret or write access leaks out of CI).
#
# Input: .github/workflows/*.yml (yaml).
#
#   - the workflow sets top-level `permissions` with `contents: read`;
#   - no permission, top-level or per job, is `write` or `write-all`.
# Without top-level `permissions` the token gets the repository default,
# which can be read-write.
#   - every `uses:` names a full commit SHA (40 hex), because a tag can be moved
#     (hard rule 6: pin every version exactly). Local actions (`./...`) are exempt.
package github

deny contains msg if {
	object.get(input, ["permissions", "contents"], null) != "read"
	msg := "workflow must set top-level `permissions:` with `contents: read`, so the GITHUB_TOKEN is read-only"
}

deny contains msg if {
	input.permissions == "write-all"
	msg := "workflow sets `permissions: write-all`; grant `contents: read` only"
}

deny contains msg if {
	some scope, level in input.permissions
	level == "write"
	msg := sprintf("workflow grants `%s: write` at top level; the token must stay read-only", [scope])
}

deny contains msg if {
	some job_name, job in input.jobs
	job.permissions == "write-all"
	msg := sprintf("job %q sets `permissions: write-all`; the token must stay read-only", [job_name])
}

deny contains msg if {
	some job_name, job in input.jobs
	some scope, level in job.permissions
	level == "write"
	msg := sprintf("job %q grants `%s: write`; the token must stay read-only", [job_name, scope])
}

deny contains msg if {
	some job_name, job in input.jobs
	some step in job.steps
	uses := step.uses
	not startswith(uses, "./")
	not regex.match(`^[^@]+@[0-9a-f]{40}$`, uses)
	msg := sprintf("job %q uses %q; pin the action to a full commit SHA and note the tag in a comment", [job_name, uses])
}
