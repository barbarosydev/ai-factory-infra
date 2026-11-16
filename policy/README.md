# Conftest policies

[Conftest](https://www.conftest.dev/) checks that the written hard rules in `AGENTS.md` still hold across the repo's Terraform, YAML and JSON files.
Each rule lives in its own Rego package next to a `*_test.rego` file, and runs only against the files listed for it.
Each `.rego` file starts with a comment that says what it checks and what it does not.

| # | Rule | Package (file) | Input files | Hard rule |
| --- | --- | --- | --- | --- |
| 1 | `kubernetes_secret_v1` uses `data_wo` and `data_wo_revision`, never `data`, `string_data` or `binary_data`; no `resource "random_password"` | `terraform.secrets` (`terraform_secrets.rego`) | `terraform/modules/*/*.tf`, `terraform/environments/local/*.tf` | 5 |
| 2 | `helm_release` sets `version`, `cleanup_on_fail = true`, `max_history = 5`, `wait = true` and a `timeout` | `terraform.helm` (`terraform_helm.rego`) | same as 1 | 6, `.claude/rules/terraform.md` |
| 3 | Kubernetes and Helm providers set `config_path` and `config_context` | `terraform.providers` (`terraform_providers.rego`) | `terraform/environments/local/providers.tf` | 1 |
| 4 | Every image is pinned by digest (`@sha256:` + 64 hex) and none uses `latest` | `images` (`images.rego`) | `terraform/environments/local/variables.tf`, `cluster/k3d-config.yaml`, `.mcp.json` | 6 |
| 5 | k3d ports and API bind to `127.0.0.1`; k3d does not update or switch the default kubeconfig | `k3d` (`k3d.rego`) | `cluster/k3d-config.yaml` | 1 |
| 6 | Workflows set top-level `permissions: contents: read` and grant nothing `write` | `github` (`github_workflows.rego`) | `.github/workflows/*.yml` | 5 |
| 7 | `.claude/settings.json` still denies reading state, tfvars, `.env` and kubeconfig, and still wires the guard hooks | `claude` (`claude_settings.rego`) | `.claude/settings.json` | 1, 4, 5 |

## Run

`task lint` runs these commands from the repo root:

```bash
conftest verify --no-color --policy policy
conftest test --no-color --policy policy --namespace terraform.secrets --namespace terraform.helm terraform/modules/*/*.tf terraform/environments/local/*.tf
conftest test --no-color --policy policy --namespace terraform.providers terraform/environments/local/providers.tf
conftest test --no-color --policy policy --namespace images terraform/environments/local/variables.tf cluster/k3d-config.yaml .mcp.json
conftest test --no-color --policy policy --namespace k3d cluster/k3d-config.yaml
conftest test --no-color --policy policy --namespace github .github/workflows/*.yml
conftest test --no-color --policy policy --namespace claude .claude/settings.json
```

`conftest verify` runs the unit tests (`test_*` rules in `*_test.rego`); each rule has passing and failing inputs shaped like `conftest parse` output.
Conftest picks the parser from the file extension (`.tf` is HCL2, `.yaml`/`.yml` YAML, `.json` JSON). To see what a rule receives, run `conftest parse <file>`.
Never point Conftest at `terraform.tfstate`, tfvars, `.env` or `.kube/`: the globs above list Terraform source files only (hard rule 4).

## Where a check belongs

| Tool | Checks |
| --- | --- |
| tflint | Terraform lint: deprecated syntax, unused declarations, provider-specific mistakes |
| Variable `validation {}` blocks | The value of one input, such as an image tag format in a module |
| `terraform test` | What a module does with its inputs |
| Conftest (this folder) | Repo-wide conventions across file types that no other tool sees together |

A rule that fits tflint or a variable validation goes there instead.
Keep this set at about seven rules; add one only for a written hard rule that nothing else checks, and drop one when another tool takes it over.

## Not covered

- `PROBE_IMAGE` in `scripts/lib/common.sh`: Conftest has no bash parser.
- Images inside Helm values templates (`*.yaml.tftpl`): the module variables' validation blocks check their format.
- GitHub Actions pinned by commit SHA: they are pinned by tag today; that check comes with a later change.
- What the guard hooks do: `tests/hooks/run.sh` tests that. Rule 7 only checks that they are wired.
