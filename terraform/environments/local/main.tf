resource "kubernetes_namespace_v1" "ai_platform" {
  metadata {
    name = var.namespace
  }
}

module "postgres" {
  source = "../../modules/postgres"

  namespace        = kubernetes_namespace_v1.ai_platform.metadata[0].name
  postgres_version = var.postgres_version
}

module "model_backend" {
  source = "../../modules/model-backend"

  namespace = kubernetes_namespace_v1.ai_platform.metadata[0].name
}

module "litellm" {
  source = "../../modules/litellm"

  namespace       = kubernetes_namespace_v1.ai_platform.metadata[0].name
  db_endpoint     = module.postgres.rw_service_name
  db_secret_name  = module.postgres.user_secret_names["litellm"]
  ollama_api_base = module.model_backend.api_base
  model_routes    = var.model_routes

  depends_on = [
    module.postgres,
    module.model_backend,
  ]
}
