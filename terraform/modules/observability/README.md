# Observability Module (Arize Phoenix)

Deploys a single digest-pinned Arize Phoenix instance backed by CloudNativePG PostgreSQL and exposed locally via Traefik (`phoenix.localhost`).

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
| [kubernetes_deployment_v1.phoenix](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment_v1) | resource |
| [kubernetes_ingress_v1.phoenix](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/ingress_v1) | resource |
| [kubernetes_service_v1.phoenix](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_db_endpoint"></a> [db\_endpoint](#input\_db\_endpoint) | PostgreSQL read-write Service hostname. | `string` | n/a | yes |
| <a name="input_db_name"></a> [db\_name](#input\_db\_name) | PostgreSQL database name dedicated to Phoenix. | `string` | `"phoenix"` | no |
| <a name="input_db_port"></a> [db\_port](#input\_db\_port) | PostgreSQL TCP port. | `number` | `5432` | no |
| <a name="input_db_secret_name"></a> [db\_secret\_name](#input\_db\_secret\_name) | Kubernetes Secret name containing PostgreSQL username and password keys. | `string` | n/a | yes |
| <a name="input_http_port"></a> [http\_port](#input\_http\_port) | HTTP UI and OTLP HTTP/protobuf receiver port exposed by Phoenix. | `number` | `6006` | no |
| <a name="input_image_name"></a> [image\_name](#input\_image\_name) | Arize Phoenix container image pinned by exact tag and multi-arch index digest (repository:tag@sha256:...). | `string` | n/a | yes |
| <a name="input_ingress_host"></a> [ingress\_host](#input\_ingress\_host) | Hostname for the Traefik Ingress exposing Arize Phoenix. | `string` | `"phoenix.localhost"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace where Arize Phoenix is deployed. | `string` | n/a | yes |
| <a name="input_retention_days"></a> [retention\_days](#input\_retention\_days) | Default trace retention policy in days applied by Phoenix. | `number` | `3` | no |
| <a name="input_service_name"></a> [service\_name](#input\_service\_name) | Kubernetes Deployment and Service name for Arize Phoenix. | `string` | `"phoenix"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ingress_url"></a> [ingress\_url](#output\_ingress\_url) | Local HTTP URL for the Arize Phoenix UI via Traefik. |
| <a name="output_otlp_http_base_url"></a> [otlp\_http\_base\_url](#output\_otlp\_http\_base\_url) | Host OTLP HTTP base URL via Traefik (OpenTelemetry SDKs append /v1/traces). |
| <a name="output_otlp_http_traces_endpoint"></a> [otlp\_http\_traces\_endpoint](#output\_otlp\_http\_traces\_endpoint) | Full host OTLP HTTP/protobuf traces ingestion endpoint. |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | Kubernetes Service name for Arize Phoenix. |
<!-- END_TF_DOCS -->
