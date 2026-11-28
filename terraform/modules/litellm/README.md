# terraform/modules/litellm

Installs the official LiteLLM Helm chart (`oci://ghcr.io/berriai/litellm-helm`, version `1.109.1`) backed by PostgreSQL, configures the Ollama model routes (`pm-agent`, `dev-agent`, `test-agent`, `sec-agent`), exposes `http://litellm.localhost:8080` through Traefik, and provisions the master key and one virtual key per agent without storing any key in Terraform state.

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
| [helm_release.litellm](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_secret_v1.agent_key](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.master_key](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_agent_max_budget"></a> [agent\_max\_budget](#input\_agent\_max\_budget) | Per-agent virtual key budget in USD. | `number` | `100` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Pinned LiteLLM Helm chart and container image version. | `string` | `"1.109.1"` | no |
| <a name="input_db_endpoint"></a> [db\_endpoint](#input\_db\_endpoint) | PostgreSQL read-write Service hostname. | `string` | n/a | yes |
| <a name="input_db_name"></a> [db\_name](#input\_db\_name) | PostgreSQL database name for LiteLLM. | `string` | `"litellm"` | no |
| <a name="input_db_secret_name"></a> [db\_secret\_name](#input\_db\_secret\_name) | Kubernetes Secret name containing PostgreSQL username and password. | `string` | n/a | yes |
| <a name="input_image_tag"></a> [image\_tag](#input\_image\_tag) | LiteLLM image tag and multi-arch index digest (X.Y.Z@sha256:...) for ghcr.io/berriai/litellm. | `string` | n/a | yes |
| <a name="input_ingress_host"></a> [ingress\_host](#input\_ingress\_host) | Hostname for the Traefik Ingress exposing LiteLLM. | `string` | `"litellm.localhost"` | no |
| <a name="input_input_cost_per_token"></a> [input\_cost\_per\_token](#input\_input\_cost\_per\_token) | Local reference input cost per token in USD so /ui/usage/ spend and key budget charts populate meaningfully on local Ollama models. | `number` | `2e-7` | no |
| <a name="input_model_routes"></a> [model\_routes](#input\_model\_routes) | Map of agent route name to Ollama model tag. | `map(string)` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace where LiteLLM is deployed. | `string` | n/a | yes |
| <a name="input_ollama_api_base"></a> [ollama\_api\_base](#input\_ollama\_api\_base) | In-cluster HTTP base URL for the Ollama Service. | `string` | n/a | yes |
| <a name="input_output_cost_per_token"></a> [output\_cost\_per\_token](#input\_output\_cost\_per\_token) | Local reference output cost per token in USD so /ui/usage/ spend and key budget charts populate meaningfully on local Ollama models. | `number` | `6e-7` | no |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | Helm release name for LiteLLM. | `string` | `"litellm"` | no |
| <a name="input_secret_version"></a> [secret\_version](#input\_secret\_version) | Increment to rotate the LiteLLM master key and agent virtual keys. | `number` | `4` | no |
| <a name="input_spend_logs_retention"></a> [spend\_logs\_retention](#input\_spend\_logs\_retention) | Retention window for LiteLLM spend and daily tag usage logs (e.g. 3d, 7d, 24h). | `string` | `"7d"` | no |
| <a name="input_store_prompts_in_spend_logs"></a> [store\_prompts\_in\_spend\_logs](#input\_store\_prompts\_in\_spend\_logs) | Whether LiteLLM stores request/response prompt payloads in spend logs for the Admin UI. | `bool` | `false` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_agent_key_secret_names"></a> [agent\_key\_secret\_names](#output\_agent\_key\_secret\_names) | Map of agent route name to the Kubernetes Secret holding its virtual key. |
| <a name="output_ingress_url"></a> [ingress\_url](#output\_ingress\_url) | Local HTTP URL for LiteLLM via Traefik. |
| <a name="output_masterkey_secret_name"></a> [masterkey\_secret\_name](#output\_masterkey\_secret\_name) | Kubernetes Secret name holding the LiteLLM master key. |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | Kubernetes Service name for LiteLLM. |
<!-- END_TF_DOCS -->