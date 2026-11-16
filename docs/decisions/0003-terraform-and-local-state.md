# ADR-0003: Terraform 1.17.2, Local State, and Namespace Ownership

## Context

In-cluster components (namespace, PostgreSQL operator and cluster, Ollama Service, LiteLLM, Temporal) need declarative, repeatable provisioning that can later be reused for cloud environments such as AKS.

## Decision

- Use **Terraform `1.17.2`** (pinned in `.terraform-version` and `required_version = "= 1.17.2"`) with `hashicorp/kubernetes ~> 3.5` (`3.5.0`), `hashicorp/helm ~> 3.3` (`3.3.0`), and `hashicorp/random ~> 3.8` (`3.8.1`).
- Split Terraform into reusable modules (`terraform/modules/{postgres,model-backend,litellm,temporal}`) with `values.yaml.tftpl` templates and a thin environment directory (`terraform/environments/local`).
- Let Terraform own the `ai-platform` namespace (`kubernetes_namespace_v1.ai_platform`) and store state locally in `terraform/environments/local/terraform.tfstate` (gitignored).

## Why

- Separating `cluster-setup.sh` (which only creates the k3d cluster) from Terraform (which owns `ai-platform` and everything inside it) avoids `terraform import` steps.
- Using `values.yaml.tftpl` per Helm module is cleaner to read and review than large inline HCL `set` lists while keeping variables strongly typed and validated.
- Local gitignored state is the simplest reliable setup for a single-machine sandbox.

## Consequences

- A future AKS environment only needs a new folder beside `terraform/environments/local` calling the same four modules.
- Multi-platform provider hashes (`darwin_arm64`, `linux_amd64`, `linux_arm64`) are locked in `.terraform.lock.hcl` and verified by `task lint`.
