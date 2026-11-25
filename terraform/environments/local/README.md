# terraform/environments/local

Local k3d environment: pinned providers (`kubernetes ~> 3.5`, `helm ~> 3.3`, `random ~> 3.8`), the `ai-platform` namespace, and the module calls for the local stack. State stays here, local and gitignored.

## Usage

```bash
task plan
task apply
```

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
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 3.5.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_litellm"></a> [litellm](#module\_litellm) | ../../modules/litellm | n/a |
| <a name="module_model_backend"></a> [model\_backend](#module\_model\_backend) | ../../modules/model-backend | n/a |
| <a name="module_network_policies"></a> [network\_policies](#module\_network\_policies) | ../../modules/network-policies | n/a |
| <a name="module_observability"></a> [observability](#module\_observability) | ../../modules/observability | n/a |
| <a name="module_postgres"></a> [postgres](#module\_postgres) | ../../modules/postgres | n/a |
| <a name="module_temporal"></a> [temporal](#module\_temporal) | ../../modules/temporal | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [kubernetes_namespace_v1.ai_platform](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cnpg_cluster_chart_version"></a> [cnpg\_cluster\_chart\_version](#input\_cnpg\_cluster\_chart\_version) | Pinned CloudNativePG cluster Helm chart version. | `string` | `"0.9.0"` | no |
| <a name="input_cnpg_operator_chart_version"></a> [cnpg\_operator\_chart\_version](#input\_cnpg\_operator\_chart\_version) | Pinned CloudNativePG operator Helm chart version. | `string` | `"0.29.1"` | no |
| <a name="input_cnpg_operator_image_tag"></a> [cnpg\_operator\_image\_tag](#input\_cnpg\_operator\_image\_tag) | CloudNativePG operator image tag and multi-arch index digest (ghcr.io/cloudnative-pg/cloudnative-pg); the version is the operator chart's appVersion. | `string` | `"1.30.1@sha256:923c267ec29636db3bee20f993d0ec4973fa22998e1adad37da79e4d32b5bc07"` | no |
| <a name="input_kube_context"></a> [kube\_context](#input\_kube\_context) | Kubeconfig context name for the local k3d cluster. | `string` | `"k3d-ai-factory"` | no |
| <a name="input_kubeconfig_path"></a> [kubeconfig\_path](#input\_kubeconfig\_path) | Absolute path of the project kubeconfig (a checkout's .kube/config). Empty uses this checkout's own. Set by scripts/terraform.sh so git worktrees share one cluster. | `string` | `""` | no |
| <a name="input_litellm_chart_version"></a> [litellm\_chart\_version](#input\_litellm\_chart\_version) | Pinned LiteLLM Helm chart and container image version. | `string` | `"1.109.1"` | no |
| <a name="input_litellm_image_tag"></a> [litellm\_image\_tag](#input\_litellm\_image\_tag) | LiteLLM image tag and multi-arch index digest (ghcr.io/berriai/litellm); the version must equal litellm\_chart\_version. | `string` | `"1.109.1@sha256:11175975a3093e05e92faee2fe2fe3412a3ae2fcaa849eb0fe25d5f0d8bcb2e9"` | no |
| <a name="input_litellm_store_prompts"></a> [litellm\_store\_prompts](#input\_litellm\_store\_prompts) | Whether LiteLLM stores request/response prompt payloads in spend logs for the Admin UI (false = metadata-only by default). | `bool` | `false` | no |
| <a name="input_model_routes"></a> [model\_routes](#input\_model\_routes) | Map of agent route name to Ollama model tag. | `map(string)` | <pre>{<br/>  "dev-agent": "gemma4:e4b",<br/>  "pm-agent": "gemma4:12b",<br/>  "sec-agent": "gemma4:e4b",<br/>  "test-agent": "gemma4:e4b"<br/>}</pre> | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace for the AI platform stack. | `string` | `"ai-platform"` | no |
| <a name="input_phoenix_image_name"></a> [phoenix\_image\_name](#input\_phoenix\_image\_name) | Arize Phoenix container image pinned by exact tag and multi-arch index digest (arizephoenix/phoenix:version-X.Y.Z@sha256:...). | `string` | `"arizephoenix/phoenix:version-22.0.1@sha256:cc8c5e545389a6aae9523beaf92eb067fdaeae59d2166093d60856f89bf7ee34"` | no |
| <a name="input_phoenix_retention_days"></a> [phoenix\_retention\_days](#input\_phoenix\_retention\_days) | Default trace retention policy in days configured on Arize Phoenix. | `number` | `3` | no |
| <a name="input_postgres_image_name"></a> [postgres\_image\_name](#input\_postgres\_image\_name) | PostgreSQL container image as repository:MAJOR.MINOR@sha256:digest (multi-arch index digest). The major must equal postgres\_version. | `string` | `"ghcr.io/cloudnative-pg/postgresql:18.6@sha256:899d3ed526b659d77935dde0e6bf2d69dbbf17d3d8c6486ca8cfd04bd3c18533"` | no |
| <a name="input_postgres_version"></a> [postgres\_version](#input\_postgres\_version) | PostgreSQL major version supported by Temporal 1.32 and CloudNativePG. | `string` | `"18"` | no |
| <a name="input_temporal_admin_tools_image_tag"></a> [temporal\_admin\_tools\_image\_tag](#input\_temporal\_admin\_tools\_image\_tag) | temporalio/admin-tools image tag and multi-arch index digest; the version must equal the temporal\_server\_image\_tag version. | `string` | `"1.32.2@sha256:4a95866efba29d7e17ab012df5232795e8b0ad0f7d5f9d1ec4df321f7792a754"` | no |
| <a name="input_temporal_chart_version"></a> [temporal\_chart\_version](#input\_temporal\_chart\_version) | Pinned Temporal Helm chart version. | `string` | `"1.8.0"` | no |
| <a name="input_temporal_server_image_tag"></a> [temporal\_server\_image\_tag](#input\_temporal\_server\_image\_tag) | temporalio/server image tag and multi-arch index digest. | `string` | `"1.32.2@sha256:7bf69188a6232fea14869b9cef3d94aa82a1601d99517f7e86c71f22da4e0670"` | no |
| <a name="input_temporal_ui_image_tag"></a> [temporal\_ui\_image\_tag](#input\_temporal\_ui\_image\_tag) | temporalio/ui image tag and multi-arch index digest. | `string` | `"2.56.1@sha256:584dd3408ab8333888d50b12d4a683e550e963409bf95fa2c9159d40d7cb825f"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_litellm_agent_key_secrets"></a> [litellm\_agent\_key\_secrets](#output\_litellm\_agent\_key\_secrets) | Map of agent route name to the Kubernetes Secret holding its virtual key. |
| <a name="output_litellm_masterkey_secret"></a> [litellm\_masterkey\_secret](#output\_litellm\_masterkey\_secret) | Kubernetes Secret name holding the LiteLLM master key. |
| <a name="output_litellm_url"></a> [litellm\_url](#output\_litellm\_url) | Local HTTP URL for LiteLLM via Traefik. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Kubernetes namespace hosting the AI platform stack. |
| <a name="output_ollama_service"></a> [ollama\_service](#output\_ollama\_service) | Kubernetes Service name routing to Ollama on the Mac. |
| <a name="output_phoenix_otlp_http_base_url"></a> [phoenix\_otlp\_http\_base\_url](#output\_phoenix\_otlp\_http\_base\_url) | Host OTLP HTTP base URL for Arize Phoenix via Traefik. |
| <a name="output_phoenix_otlp_http_traces_endpoint"></a> [phoenix\_otlp\_http\_traces\_endpoint](#output\_phoenix\_otlp\_http\_traces\_endpoint) | Full host OTLP HTTP/protobuf traces ingestion endpoint for Arize Phoenix. |
| <a name="output_phoenix_service"></a> [phoenix\_service](#output\_phoenix\_service) | Kubernetes Service name for Arize Phoenix. |
| <a name="output_phoenix_url"></a> [phoenix\_url](#output\_phoenix\_url) | Local HTTP URL for the Arize Phoenix UI via Traefik. |
| <a name="output_postgres_cluster_name"></a> [postgres\_cluster\_name](#output\_postgres\_cluster\_name) | Name of the CloudNativePG PostgreSQL cluster. |
| <a name="output_postgres_databases"></a> [postgres\_databases](#output\_postgres\_databases) | Provisioned PostgreSQL databases. |
| <a name="output_postgres_rw_service"></a> [postgres\_rw\_service](#output\_postgres\_rw\_service) | Kubernetes Service name for read-write PostgreSQL connections. |
| <a name="output_postgres_user_secrets"></a> [postgres\_user\_secrets](#output\_postgres\_user\_secrets) | Kubernetes Secret names holding the PostgreSQL user credentials. |
| <a name="output_temporal_frontend_service"></a> [temporal\_frontend\_service](#output\_temporal\_frontend\_service) | Kubernetes Service name for the Temporal gRPC frontend. |
| <a name="output_temporal_grpc_endpoint"></a> [temporal\_grpc\_endpoint](#output\_temporal\_grpc\_endpoint) | Host gRPC endpoint for the Temporal CLI and SDK workers on the Mac. |
| <a name="output_temporal_web_url"></a> [temporal\_web\_url](#output\_temporal\_web\_url) | Local HTTP URL for the Temporal Web UI via Traefik. |
<!-- END_TF_DOCS -->