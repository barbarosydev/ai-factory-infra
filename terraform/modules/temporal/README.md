# terraform/modules/temporal

Installs the official Temporal Helm chart (`https://go.temporal.io/helm-charts`, version `1.8.0`, server `1.32.2`, Web UI `2.56.1`) backed by PostgreSQL (`temporal` and `temporal_visibility` databases with SQL visibility and no Elasticsearch), creates the `default` namespace via in-cluster Jobs without Helm hooks, exposes the Web UI at `http://temporal.localhost:8080` through Traefik, and exposes the frontend gRPC endpoint on `localhost:7233` via k3s ServiceLB.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | = 1.17.2 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3.3 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 3.3 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.temporal](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_admin_tools_image_tag"></a> [admin\_tools\_image\_tag](#input\_admin\_tools\_image\_tag) | temporalio/admin-tools image tag and multi-arch index digest (X.Y.Z@sha256:...) for the schema and namespace Jobs. | `string` | n/a | yes |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Pinned Temporal Helm chart version. | `string` | `"1.8.0"` | no |
| <a name="input_db_endpoint"></a> [db\_endpoint](#input\_db\_endpoint) | PostgreSQL read-write Service hostname. | `string` | n/a | yes |
| <a name="input_db_port"></a> [db\_port](#input\_db\_port) | PostgreSQL TCP port. | `number` | `5432` | no |
| <a name="input_db_secret_name"></a> [db\_secret\_name](#input\_db\_secret\_name) | Kubernetes Secret name containing PostgreSQL credentials for the Temporal user. | `string` | n/a | yes |
| <a name="input_db_user"></a> [db\_user](#input\_db\_user) | PostgreSQL role owning the Temporal databases. | `string` | `"temporal"` | no |
| <a name="input_default_db_name"></a> [default\_db\_name](#input\_default\_db\_name) | PostgreSQL database name for Temporal default persistence store. | `string` | `"temporal"` | no |
| <a name="input_default_namespace_retention"></a> [default\_namespace\_retention](#input\_default\_namespace\_retention) | Workflow execution retention period for the default Temporal namespace. | `string` | `"3d"` | no |
| <a name="input_grpc_port"></a> [grpc\_port](#input\_grpc\_port) | Frontend gRPC TCP port exposed via LoadBalancer to the Mac host. | `number` | `7233` | no |
| <a name="input_ingress_host"></a> [ingress\_host](#input\_ingress\_host) | Hostname for the Traefik Ingress exposing the Temporal Web UI. | `string` | `"temporal.localhost"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace where Temporal is deployed. | `string` | n/a | yes |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | Helm release name for Temporal. | `string` | `"temporal"` | no |
| <a name="input_server_image_tag"></a> [server\_image\_tag](#input\_server\_image\_tag) | temporalio/server image tag and multi-arch index digest (X.Y.Z@sha256:...). | `string` | n/a | yes |
| <a name="input_ui_image_tag"></a> [ui\_image\_tag](#input\_ui\_image\_tag) | temporalio/ui image tag and multi-arch index digest (X.Y.Z@sha256:...). | `string` | n/a | yes |
| <a name="input_visibility_db_name"></a> [visibility\_db\_name](#input\_visibility\_db\_name) | PostgreSQL database name for Temporal SQL visibility store. | `string` | `"temporal_visibility"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_frontend_service_name"></a> [frontend\_service\_name](#output\_frontend\_service\_name) | Kubernetes Service name for the Temporal gRPC frontend. |
| <a name="output_grpc_endpoint"></a> [grpc\_endpoint](#output\_grpc\_endpoint) | Host gRPC endpoint for the Temporal CLI and SDK workers on the Mac. |
| <a name="output_web_url"></a> [web\_url](#output\_web\_url) | Local HTTP URL for the Temporal Web UI via Traefik. |
<!-- END_TF_DOCS -->
