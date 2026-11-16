# terraform/modules/postgres

Installs the CloudNativePG operator (`0.29.1`, operator `1.30.1`) and a single-instance PostgreSQL `16` cluster (`cluster` chart `0.9.0`) in the target namespace.

## What it provisions

- Three databases: `temporal`, `temporal_visibility` (owned by `temporal`), and `litellm` (owned by `litellm`).
- Two non-superuser roles (`temporal`, `litellm`) with `pg_hba` rules restricting each role to its own database(s).
- Passwords generated via `ephemeral "random_password"` and stored in `kubernetes_secret_v1` using write-only `data_wo`, so no password is saved in Terraform state.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | = 1.17.2 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3.3 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 3.5 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.8 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 3.3 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~> 3.5 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.cnpg_cluster](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.cnpg_operator](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_secret_v1.db_user](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_chart_version"></a> [cluster\_chart\_version](#input\_cluster\_chart\_version) | Pinned CloudNativePG cluster Helm chart version. | `string` | `"0.9.0"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the CloudNativePG cluster and Helm release. | `string` | `"ai-postgres"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace where CloudNativePG and the PostgreSQL cluster are deployed. | `string` | n/a | yes |
| <a name="input_operator_chart_version"></a> [operator\_chart\_version](#input\_operator\_chart\_version) | Pinned CloudNativePG operator Helm chart version. | `string` | `"0.29.1"` | no |
| <a name="input_operator_image_tag"></a> [operator\_image\_tag](#input\_operator\_image\_tag) | CloudNativePG operator image tag and multi-arch index digest (X.Y.Z@sha256:...); also used for the instance manager in PostgreSQL pods. | `string` | n/a | yes |
| <a name="input_password_version"></a> [password\_version](#input\_password\_version) | Increment to rotate the generated database user passwords. | `number` | `1` | no |
| <a name="input_postgres_image_name"></a> [postgres\_image\_name](#input\_postgres\_image\_name) | PostgreSQL container image as repository:MAJOR.MINOR@sha256:digest (multi-arch index digest). The major must equal postgres\_version. | `string` | n/a | yes |
| <a name="input_postgres_version"></a> [postgres\_version](#input\_postgres\_version) | PostgreSQL major version supported by Temporal 1.32 and CloudNativePG. | `string` | `"16"` | no |
| <a name="input_storage_size"></a> [storage\_size](#input\_storage\_size) | Persistent volume size for the PostgreSQL data directory. | `string` | `"8Gi"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the CloudNativePG cluster. |
| <a name="output_databases"></a> [databases](#output\_databases) | Names of the application databases provisioned in the PostgreSQL cluster. |
| <a name="output_rw_service_name"></a> [rw\_service\_name](#output\_rw\_service\_name) | Kubernetes Service name for read-write PostgreSQL connections. |
| <a name="output_user_secret_names"></a> [user\_secret\_names](#output\_user\_secret\_names) | Map of PostgreSQL role name to its Kubernetes basic-auth Secret name. |
<!-- END_TF_DOCS -->