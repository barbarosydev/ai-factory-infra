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
