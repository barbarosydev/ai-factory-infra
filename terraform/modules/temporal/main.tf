# atomic is intentionally false: schema and namespace setup Jobs run alongside
# the server Deployments without Helm hooks (useHelmHooks: false), and first-time
# image pulls for temporalio/server, temporalio/admin-tools, and temporalio/ui
# can take several minutes; scripts/terraform.sh verifies Job completion and rollout.
resource "helm_release" "temporal" {
  name            = var.release_name
  repository      = "https://go.temporal.io/helm-charts"
  chart           = "temporal"
  version         = var.chart_version
  namespace       = var.namespace
  wait            = true
  timeout         = 900
  cleanup_on_fail = true
  max_history     = 5

  values = [
    templatefile("${path.module}/values.yaml.tftpl", {
      release_name                = var.release_name
      server_image_tag            = var.server_image_tag
      ui_image_tag                = var.ui_image_tag
      db_endpoint                 = var.db_endpoint
      db_port                     = var.db_port
      default_db_name             = var.default_db_name
      visibility_db_name          = var.visibility_db_name
      db_user                     = var.db_user
      db_secret_name              = var.db_secret_name
      default_namespace_retention = var.default_namespace_retention
      ingress_host                = var.ingress_host
      grpc_port                   = var.grpc_port
    })
  ]
}
