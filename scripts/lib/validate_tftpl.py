#!/usr/bin/env python3
"""Offline validator for Terraform `.yaml.tftpl` Helm values templates.

Checks every module under `terraform/modules/*/`:
  1. Variable alignment: keys passed in `templatefile("${path.module}/<name>.yaml.tftpl", { ... })`
     in `main.tf` must match the `${var}` placeholders used inside `<name>.yaml.tftpl`.
  2. Rendered YAML validity: rendering `<name>.yaml.tftpl` with representative mock values
     must parse cleanly with `yq eval 'true' -`.

Runs in `<100ms` inside `scripts/lint.sh` (`task lint` and `task ci`).
"""
from __future__ import annotations

import pathlib
import re
import subprocess
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]

# Representative mock values for rendering `.yaml.tftpl` templates into concrete YAML.
MOCK_VALUES: dict[str, str] = {
    "cluster_name": "ai-postgres",
    "postgres_version": "16",
    "postgres_image_name": "ghcr.io/cloudnative-pg/postgresql:16.15@sha256:0000000000000000000000000000000000000000000000000000000000000000",
    "operator_image_tag": "1.30.1@sha256:0000000000000000000000000000000000000000000000000000000000000000",
    "storage_size": "5Gi",
    "release_name": "release",
    "chart_version": "1.109.1",
    "image_tag": "1.109.1@sha256:0000000000000000000000000000000000000000000000000000000000000000",
    "masterkey_secret_name": "litellm-masterkey",
    "db_endpoint": "ai-postgres-cluster-rw",
    "db_port": "5432",
    "db_name": "litellm",
    "default_db_name": "temporal",
    "visibility_db_name": "temporal_visibility",
    "db_user": "temporal",
    "db_secret_name": "ai-postgres-credentials",
    "ollama_api_base": "http://ollama:11434",
    "ingress_host": "service.localhost",
    "agent_max_budget": "100",
    "store_prompts_in_spend_logs": "true",
    "secret_version": "1",
    "server_image_tag": "1.32.2@sha256:0000000000000000000000000000000000000000000000000000000000000000",
    "admin_tools_image_tag": "1.32.2@sha256:0000000000000000000000000000000000000000000000000000000000000000",
    "ui_image_tag": "2.56.1@sha256:0000000000000000000000000000000000000000000000000000000000000000",
    "default_namespace_retention": "3d",
    "grpc_port": "7233",
}


def extract_main_tf_template_calls(main_tf: pathlib.Path) -> dict[str, set[str]]:
    """Return `{template_filename: {passed_keys}}` for each `templatefile(...)` call in `main.tf`."""
    text = main_tf.read_text(encoding="utf-8")
    calls: dict[str, set[str]] = {}
    pattern = re.compile(
        r'templatefile\(\s*"\$\{path\.module\}/([^"]+\.yaml\.tftpl)"\s*,\s*\{([^}]*)\}\s*\)',
        re.DOTALL,
    )
    for match in pattern.finditer(text):
        tpl_name = match.group(1)
        body = match.group(2)
        keys = set(re.findall(r"(?m)^\s*([a-zA-Z0-9_]+)\s*=", body))
        calls[tpl_name] = keys
    return calls


def extract_tftpl_variables(tpl_text: str) -> set[str]:
    """Extract Terraform template variable identifiers referenced in `.yaml.tftpl`."""
    vars_found: set[str] = set()
    builtins = {
        "true", "false", "in", "for", "if", "endif", "endfor",
        "agent", "model", "_", "sha256", "jsonencode", "keys", "upper", "replace",
    }
    # Match `${...}` (allowing one level of nested `{...}`) and `%{ ... ~}`
    for expr in re.findall(
        r"\$\{((?:[^{}]|\{[^{}]*\})+)\}|%\{\s*(?:for\s+[a-zA-Z0-9_,\s]+\s+in\s+|if\s+)([^}~]+)",
        tpl_text,
    ):
        raw = (expr[0] or expr[1]).strip()
        # Strip string literals and HCL object keys (`key =`) before scanning identifiers
        raw = re.sub(r'"[^"]*"', "", raw)
        raw = re.sub(r"\b[a-zA-Z_][a-zA-Z0-9_]*\s*=(?!=)", "", raw)
        for ident in re.findall(r"\b([a-zA-Z_][a-zA-Z0-9_]*)\b", raw):
            if ident not in builtins:
                vars_found.add(ident)
    return vars_found


def render_tftpl_for_yaml_check(tpl_text: str) -> str:
    """Render a `.yaml.tftpl` into concrete YAML for syntax validation."""
    # Expand `%{ if postgres_image_name != "" ~} ... %{ endif ~}` blocks
    rendered = re.sub(
        r"%\{\s*if\s+[^}]*~\}\n?(.*?)%\{\s*endif\s*~\}\n?",
        lambda m: m.group(1).replace("${postgres_image_name}", "ghcr.io/cloudnative-pg/postgresql:16"),
        tpl_text,
        flags=re.DOTALL,
    )
    # Expand `%{ for agent, ... in model_routes ~} ... %{ endfor ~}` loops
    rendered = re.sub(
        r"%\{\s*for\s+agent\s*,\s*(?:model|_)\s+in\s+model_routes\s*~\}\n?(.*?)%\{\s*endfor\s*~\}\n?",
        lambda m: (
            m.group(1)
            .replace('${upper(replace(agent, "-", "_"))}', "PM_AGENT")
            .replace("${agent}", "pm-agent")
            .replace("${model}", "gemma4:12b")
        ),
        rendered,
        flags=re.DOTALL,
    )
    # Replace complex expressions
    rendered = re.sub(r"\$\{sha256\(jsonencode\((?:[^{}]|\{[^{}]*\})+\)\)\}", "0123456789abcdef", rendered)
    rendered = rendered.replace("${jsonencode(keys(model_routes))}", '["pm-agent"]')
    rendered = rendered.replace("${!store_prompts_in_spend_logs}", "false")
    # Replace remaining `${var}` placeholders
    for key, val in MOCK_VALUES.items():
        rendered = rendered.replace(f"${{{key}}}", val)
    return rendered


def validate_all() -> int:
    errors: list[str] = []
    modules_dir = REPO_ROOT / "terraform" / "modules"
    for mod_dir in sorted(modules_dir.iterdir()):
        if not mod_dir.is_dir():
            continue
        main_tf = mod_dir / "main.tf"
        if not main_tf.exists():
            continue
        calls = extract_main_tf_template_calls(main_tf)
        for tpl_path in sorted(mod_dir.glob("*.yaml.tftpl")):
            rel = tpl_path.relative_to(REPO_ROOT)
            tpl_text = tpl_path.read_text(encoding="utf-8")
            used_vars = extract_tftpl_variables(tpl_text)
            if tpl_path.name not in calls:
                errors.append(f"{rel}: not referenced via templatefile() in {main_tf.relative_to(REPO_ROOT)}")
                continue
            passed_vars = calls[tpl_path.name]
            missing = used_vars - passed_vars
            unused = passed_vars - used_vars
            if missing:
                errors.append(f"{rel}: variables used in template but missing in main.tf: {sorted(missing)}")
            if unused:
                errors.append(f"{rel}: variables passed in main.tf but unused in template: {sorted(unused)}")

            rendered = render_tftpl_for_yaml_check(tpl_text)
            if "${" in rendered or "%{" in rendered:
                errors.append(f"{rel}: unexpanded template expression after mock render")
                continue

            proc = subprocess.run(
                ["yq", "eval", "true", "-"],
                input=rendered.encode("utf-8"),
                capture_output=True,
                check=False,
            )
            if proc.returncode != 0:
                err = proc.stderr.decode("utf-8", errors="replace").strip()
                errors.append(f"{rel}: rendered YAML is invalid: {err}")

    if errors:
        for e in errors:
            print(f"FAIL  {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(validate_all())
