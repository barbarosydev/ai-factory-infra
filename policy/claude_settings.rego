# Rule 7: the Claude Code harness has not been weakened unnoticed (hard rules
# 1, 4 and 5).
#
# Input: .claude/settings.json (json). This file is Claude Code specific; the
# rule only makes a silent removal of a guard fail `task lint`.
#
#   - `permissions.deny` still blocks reading Terraform state, tfvars, .env
#     and the kubeconfig (hard rule 4), and the Terraform commands that print
#     state;
#   - the PreToolUse guard hooks are still wired to the right tools:
#     kube-guard.py, branch-guard.sh and agent-guard.sh on Bash, and
#     secret-guard.sh on Write and Edit.
# It does not check what the hooks do; tests/hooks/run.sh tests that.
package claude

required_denies := [
	"Read(**/*.tfstate)",
	"Read(**/*.tfstate.*)",
	"Read(**/*.tfvars)",
	"Read(**/*.tfvars.json)",
	"Read(**/.env)",
	"Read(**/.env.*)",
	"Read(./.kube/**)",
	"Read(~/.kube/**)",
	"Bash(terraform state*)",
	"Bash(terraform -chdir=* state*)",
	"Bash(terraform show*)",
	"Bash(terraform -chdir=* show*)",
]

# Hook script -> tools its PreToolUse matcher must cover.
required_hooks := {
	"kube-guard.py": ["Bash"],
	"branch-guard.sh": ["Bash"],
	"agent-guard.sh": ["Bash"],
	"secret-guard.sh": ["Write", "Edit"],
}

deny contains msg if {
	some rule in required_denies
	not rule in object.get(input, ["permissions", "deny"], [])
	msg := sprintf(".claude/settings.json: permissions.deny no longer contains %q; restore it (hard rule 4)", [rule])
}

# A hook is wired for a tool when some PreToolUse entry whose matcher names
# that tool runs a command ending in the hook's file name.
wired(hook, tool) if {
	some entry in input.hooks.PreToolUse
	tool in split(entry.matcher, "|")
	some h in entry.hooks
	endswith(trim_right(h.command, "\""), concat("/", ["", hook]))
}

deny contains msg if {
	some hook, tools in required_hooks
	some tool in tools
	not wired(hook, tool)
	msg := sprintf(".claude/settings.json: the PreToolUse hook %s is no longer wired for %s; restore it under hooks.PreToolUse", [hook, tool])
}
