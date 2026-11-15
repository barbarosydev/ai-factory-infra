#!/usr/bin/env python3
"""PreToolUse hook for Bash: keep Claude on the project cluster and away from secrets.

Blocks (exit 2, reason on stderr, which Claude reads):
  * kubectl, helm or k9s run directly unless --kubeconfig points at this repo's
    .kube/config, and any --context / --kube-context other than k3d-ai-factory.
    `task kube -- ...` is the normal path and always pins both.
  * kubectx, kubens and `kubectl config` commands that switch or edit contexts.
  * Environment overrides that could point Terraform's providers elsewhere.
  * terraform state, show, output and console, which print state values.
  * Printing Kubernetes Secret values (`get secret ... -o ...`).
  * Reading state, tfvars, .env or the kubeconfig with cat, grep, head and friends.

Commands nested in `bash -c "..."`, `sh -c`, `eval`, `$(...)` and backticks are
checked too. Everything else passes (exit 0). Standard library only.
Tests: tests/hooks/run.sh (task ci runs them).
"""
import json
import os
import re
import shlex
import sys

KUBE_CONTEXT = "k3d-ai-factory"
PROJECT_DIR = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
PROJECT_KUBECONFIG = os.path.realpath(os.path.join(PROJECT_DIR, ".kube", "config"))

CLUSTER_TOOLS = {"kubectl", "helm", "k9s"}
CONTEXT_SWITCHERS = {"kubectx", "kubens"}
KUBECTL_CONFIG_WRITES = {
    "use-context", "set-context", "delete-context", "rename-context",
    "set-cluster", "set-credentials", "unset", "set", "view",
}
TERRAFORM_STATE_READERS = {"state", "show", "output", "console"}
READERS = {
    "cat", "less", "more", "head", "tail", "bat", "strings", "xxd", "od", "base64",
    "grep", "rg", "ag", "sed", "awk", "jq", "yq", "cp", "scp", "open", "code", "vim", "nano",
}
SECRET_PATH = re.compile(
    r"(\.tfstate(\.|$)|\.tfplan$|\.tfvars(\.json)?$|(^|/)\.env(\.[^/]*)?$|(^|/)\.kube/config$)"
)
SAFE_EXAMPLE = re.compile(r"\.example$")
SHELLS = {"bash", "sh", "zsh"}
SUBSHELL = re.compile(r"\$\(([^()]*)\)|`([^`]*)`")
OVERRIDE_VARS = {"KUBE_CONFIG_PATH", "KUBE_CONFIG_PATHS", "KUBE_CTX", "KUBE_CTX_CLUSTER", "KUBE_HOST"}


def block(reason: str) -> None:
    print(f"Blocked by .claude/hooks/kube-guard.py: {reason}", file=sys.stderr)
    sys.exit(2)


def resolve(path: str) -> str:
    path = os.path.expanduser(os.path.expandvars(path))
    if not os.path.isabs(path):
        path = os.path.join(PROJECT_DIR, path)
    return os.path.realpath(path)


def segments(command: str):
    """Split a shell line into simple commands on ; && || | and newlines."""
    lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|\n")
    lexer.whitespace_split = True
    lexer.commenters = ""
    current = []
    try:
        for token in lexer:
            if token and set(token) <= set(";&|\n"):
                if current:
                    yield current
                current = []
            else:
                current.append(token)
    except ValueError:
        # Unbalanced quotes: fall back to a plain split so the checks still run.
        yield command.split()
        return
    if current:
        yield current


def flag_value(args, *names):
    for i, arg in enumerate(args):
        for name in names:
            if arg == name and i + 1 < len(args):
                return args[i + 1]
            if arg.startswith(name + "="):
                return arg.split("=", 1)[1]
    return None


def check_segment(words) -> None:
    env = {}
    while words and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[0]):
        key, value = words[0].split("=", 1)
        env[key] = value
        words = words[1:]
    # Look through common wrappers to the real command.
    while words and words[0] in {"env", "sudo", "command", "exec", "time", "nohup"}:
        words = words[1:]
        while words and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[0]):
            key, value = words[0].split("=", 1)
            env[key] = value
            words = words[1:]
    if not words:
        return

    for key in env:
        if key in OVERRIDE_VARS:
            block(f"{key} would point Terraform at another cluster; the providers pin .kube/config.")

    tool = os.path.basename(words[0])
    args = words[1:]

    # Nested commands get the same checks as the outer line.
    if tool in SHELLS and "-c" in args and args.index("-c") + 1 < len(args):
        check_line(args[args.index("-c") + 1])
    if tool == "eval":
        check_line(" ".join(args))

    if tool in CONTEXT_SWITCHERS:
        block(f"{tool} changes your global kube context. Use `task kube -- ...` instead.")

    if tool in CLUSTER_TOOLS:
        if tool == "kubectl" and "config" in args and any(a in KUBECTL_CONFIG_WRITES for a in args[args.index("config") + 1:]):
            block("kubectl config commands can switch, edit or print kube contexts and credentials.")
        kubeconfig = flag_value(args, "--kubeconfig") or env.get("KUBECONFIG")
        if not kubeconfig or resolve(kubeconfig) != PROJECT_KUBECONFIG:
            block(
                f"{tool} must use this repo's .kube/config, never your global kubeconfig with its AKS contexts. "
                "Use `task kube -- <args>`, or pass --kubeconfig .kube/config."
            )
        context = flag_value(args, "--context", "--kube-context")
        if context and context != KUBE_CONTEXT:
            block(f"only the {KUBE_CONTEXT} context is allowed, not {context}.")

    if tool == "terraform":
        sub = [a for a in args if not a.startswith("-")]
        if sub and sub[0] in TERRAFORM_STATE_READERS:
            block(f"`terraform {sub[0]}` prints values from state, which may hold secrets.")

    # Secret values from the cluster, through kubectl or task kube.
    joined = " ".join(args)
    if (tool == "kubectl" or (tool == "task" and args[:1] == ["kube"])) and re.search(r"\bget\s+secrets?\b", joined):
        if re.search(r"(^|\s)(-o|--output)(\s|=|$)|\s-o\w", " " + joined):
            block("printing Kubernetes Secret values is not allowed; list names with `task kube -- get secrets -n <ns>`.")
    if tool in CLUSTER_TOOLS | {"task"} and re.search(r"\bsecrets?\b.*(jsonpath|go-template|base64)", joined):
        block("printing Kubernetes Secret values is not allowed.")

    # Reading secret files with shell tools.
    if tool in READERS:
        for arg in args:
            if SECRET_PATH.search(arg) and not SAFE_EXAMPLE.search(arg):
                block(f"{arg} may hold secrets (state, tfvars, .env or kubeconfig); it stays out of Claude's context.")


def check_line(command: str) -> None:
    for match in SUBSHELL.finditer(command):
        check_line(match.group(1) or match.group(2) or "")
    for words in segments(command):
        check_segment(list(words))


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return
    check_line((payload.get("tool_input") or {}).get("command") or "")


if __name__ == "__main__":
    main()
