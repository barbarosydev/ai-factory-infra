# terraform/modules/model-backend

Creates the `ollama` ExternalName Kubernetes Service pointing at `host.k3d.internal:11434`, giving LiteLLM one stable in-cluster address (`http://ollama:11434`) for models running natively on the Mac.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | = 1.17.2 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 3.5 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~> 3.5 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [kubernetes_service_v1.ollama](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_host_address"></a> [host\_address](#input\_host\_address) | DNS name of the host running Ollama. | `string` | `"host.k3d.internal"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace for the model backend Service. | `string` | n/a | yes |
| <a name="input_port"></a> [port](#input\_port) | TCP port where Ollama listens on the host. | `number` | `11434` | no |
| <a name="input_service_name"></a> [service\_name](#input\_service\_name) | Name of the Kubernetes Service exposing the model backend. | `string` | `"ollama"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_api_base"></a> [api\_base](#output\_api\_base) | In-cluster HTTP base URL for the model backend. |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | Name of the Kubernetes Service routing to the model backend. |
<!-- END_TF_DOCS -->