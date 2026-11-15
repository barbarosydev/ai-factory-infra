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
| <a name="module_postgres"></a> [postgres](#module\_postgres) | ../../modules/postgres | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [kubernetes_namespace_v1.ai_platform](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cnpg_cluster_chart_version"></a> [cnpg\_cluster\_chart\_version](#input\_cnpg\_cluster\_chart\_version) | Pinned CloudNativePG cluster Helm chart version. | `string` | `"0.9.0"` | no |
| <a name="input_cnpg_operator_chart_version"></a> [cnpg\_operator\_chart\_version](#input\_cnpg\_operator\_chart\_version) | Pinned CloudNativePG operator Helm chart version. | `string` | `"0.29.1"` | no |
| <a name="input_kube_context"></a> [kube\_context](#input\_kube\_context) | Kubeconfig context name for the local k3d cluster. | `string` | `"k3d-ai-factory"` | no |
| <a name="input_litellm_chart_version"></a> [litellm\_chart\_version](#input\_litellm\_chart\_version) | Pinned LiteLLM Helm chart and container image version. | `string` | `"1.109.1"` | no |
| <a name="input_litellm_store_prompts"></a> [litellm\_store\_prompts](#input\_litellm\_store\_prompts) | Whether LiteLLM stores request/response prompt payloads in spend logs for the Admin UI. | `bool` | `true` | no |
| <a name="input_model_routes"></a> [model\_routes](#input\_model\_routes) | Map of agent route name to Ollama model tag. | `map(string)` | <pre>{<br/>  "dev-agent": "gemma4:e4b",<br/>  "pm-agent": "gemma4:12b",<br/>  "sec-agent": "gemma4:e4b"<br/>}</pre> | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace for the AI platform stack. | `string` | `"ai-platform"` | no |
| <a name="input_postgres_image_name"></a> [postgres\_image\_name](#input\_postgres\_image\_name) | Optional explicit PostgreSQL container image (tag or tag@sha256:digest). Empty uses the CloudNativePG default for postgres\_version. | `string` | `""` | no |
| <a name="input_postgres_version"></a> [postgres\_version](#input\_postgres\_version) | PostgreSQL major version supported by Temporal 1.32 and CloudNativePG. | `string` | `"16"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_litellm_agent_key_secrets"></a> [litellm\_agent\_key\_secrets](#output\_litellm\_agent\_key\_secrets) | Map of agent route name to the Kubernetes Secret holding its virtual key. |
| <a name="output_litellm_masterkey_secret"></a> [litellm\_masterkey\_secret](#output\_litellm\_masterkey\_secret) | Kubernetes Secret name holding the LiteLLM master key. |
| <a name="output_litellm_url"></a> [litellm\_url](#output\_litellm\_url) | Local HTTP URL for LiteLLM via Traefik. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Kubernetes namespace hosting the AI platform stack. |
| <a name="output_ollama_service"></a> [ollama\_service](#output\_ollama\_service) | Kubernetes Service name routing to Ollama on the Mac. |
| <a name="output_postgres_cluster_name"></a> [postgres\_cluster\_name](#output\_postgres\_cluster\_name) | Name of the CloudNativePG PostgreSQL cluster. |
| <a name="output_postgres_databases"></a> [postgres\_databases](#output\_postgres\_databases) | Provisioned PostgreSQL databases. |
| <a name="output_postgres_rw_service"></a> [postgres\_rw\_service](#output\_postgres\_rw\_service) | Kubernetes Service name for read-write PostgreSQL connections. |
| <a name="output_postgres_user_secrets"></a> [postgres\_user\_secrets](#output\_postgres\_user\_secrets) | Kubernetes Secret names holding the PostgreSQL user credentials. |
<!-- END_TF_DOCS -->