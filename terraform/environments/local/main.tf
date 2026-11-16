resource "kubernetes_namespace_v1" "ai_platform" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/part-of"    = "ai-factory"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

module "postgres" {
  source = "../../modules/postgres"

  namespace              = kubernetes_namespace_v1.ai_platform.metadata[0].name
  operator_chart_version = var.cnpg_operator_chart_version
  cluster_chart_version  = var.cnpg_cluster_chart_version
  postgres_version       = var.postgres_version
  postgres_image_name    = var.postgres_image_name
}

module "model_backend" {
  source = "../../modules/model-backend"

  namespace = kubernetes_namespace_v1.ai_platform.metadata[0].name
}

module "litellm" {
  source = "../../modules/litellm"

  namespace                   = kubernetes_namespace_v1.ai_platform.metadata[0].name
  chart_version               = var.litellm_chart_version
  db_endpoint                 = module.postgres.rw_service_name
  db_secret_name              = module.postgres.user_secret_names["litellm"]
  ollama_api_base             = module.model_backend.api_base
  model_routes                = var.model_routes
  store_prompts_in_spend_logs = var.litellm_store_prompts

  depends_on = [
    module.postgres,
    module.model_backend,
  ]
}

module "temporal" {
  source = "../../modules/temporal"

  namespace        = kubernetes_namespace_v1.ai_platform.metadata[0].name
  chart_version    = var.temporal_chart_version
  server_image_tag = var.temporal_server_image_tag
  ui_image_tag     = var.temporal_ui_image_tag
  db_endpoint      = module.postgres.rw_service_name
  db_secret_name   = module.postgres.user_secret_names["temporal"]

  depends_on = [
    module.postgres,
  ]
}
