resource "kubernetes_service_v1" "ollama" {
  metadata {
    name      = var.service_name
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"       = var.service_name
      "app.kubernetes.io/part-of"    = "ai-factory"
      "app.kubernetes.io/component"  = "model-backend"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    type          = "ExternalName"
    external_name = var.host_address

    port {
      name        = "http"
      port        = var.port
      target_port = var.port
      protocol    = "TCP"
    }
  }
}
