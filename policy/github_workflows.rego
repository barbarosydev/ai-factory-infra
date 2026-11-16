# Rule 6: GitHub workflows run with a read-only token (hard rule 5: no
# secret or write access leaks out of CI).
#
# Input: .github/workflows/*.yml (yaml).
#
#   - the workflow sets top-level `permissions` with `contents: read`;
#   - no permission, top-level or per job, is `write` or `write-all`.
# Without top-level `permissions` the token gets the repository default,
# which can be read-write.
#
# Not checked yet: actions pinned by commit SHA (they are pinned by tag today;
# that change belongs to a later work package).
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
