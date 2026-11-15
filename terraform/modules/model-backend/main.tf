resource "kubernetes_service_v1" "ollama" {
  metadata {
    name      = var.service_name
    namespace = var.namespace
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
