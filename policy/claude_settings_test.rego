package claude

hook(name) := {"type": "command", "command": concat("", ["\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/", name])}

bash_hooks := {"matcher": "Bash", "hooks": [hook("kube-guard.py"), hook("branch-guard.sh"), hook("agent-guard.sh")]}

write_hooks := {"matcher": "Write|Edit", "hooks": [hook("secret-guard.sh")]}

good_settings := {
	"permissions": {"allow": ["Bash(task ci*)"], "deny": required_denies},
	"hooks": {"PreToolUse": [bash_hooks, write_hooks]},
}

test_full_harness_passes if {
	count(deny) == 0 with input as good_settings
}

test_missing_state_deny_fails if {
	denies := [r | some r in required_denies; r != "Read(**/*.tfstate)"]
	deny[".claude/settings.json: permissions.deny no longer contains \"Read(**/*.tfstate)\"; restore it (hard rule 4)"] with input as object.union(good_settings, {"permissions": {"deny": denies}})
}

test_missing_kube_guard_fails if {
	weakened := {"matcher": "Bash", "hooks": [hook("branch-guard.sh"), hook("agent-guard.sh")]}
	deny[".claude/settings.json: the PreToolUse hook kube-guard.py is no longer wired for Bash; restore it under hooks.PreToolUse"] with input as object.union(good_settings, {"hooks": {"PreToolUse": [weakened, write_hooks]}})
}

test_secret_guard_on_write_only_fails if {
	narrowed := {"matcher": "Write", "hooks": [hook("secret-guard.sh")]}
	some msg in deny with input as object.union(good_settings, {"hooks": {"PreToolUse": [bash_hooks, narrowed]}})
	contains(msg, "secret-guard.sh is no longer wired for Edit")
}

test_no_hooks_fails if {
	count(deny) == 5 with input as {"permissions": {"deny": required_denies}}
}
