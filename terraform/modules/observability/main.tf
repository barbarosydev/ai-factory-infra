locals {
  common_labels = {
    "app.kubernetes.io/name"       = var.service_name
    "app.kubernetes.io/part-of"    = "ai-factory"
    "app.kubernetes.io/component"  = "observability"
    "app.kubernetes.io/managed-by" = "terraform"
  }
  selector_labels = {
    "app.kubernetes.io/name"      = var.service_name
    "app.kubernetes.io/component" = "observability"
  }
}

resource "kubernetes_deployment_v1" "phoenix" {
  metadata {
    name      = var.service_name
    namespace = var.namespace
    labels    = local.common_labels
  }

  wait_for_rollout = true

  spec {
    replicas = 1

    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = local.selector_labels
    }

    template {
      metadata {
        labels = local.common_labels
      }

      spec {
        container {
          name              = "phoenix"
          image             = var.image_name
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = var.http_port
            protocol       = "TCP"
          }

          env {
            name  = "PHOENIX_HOST"
            value = "0.0.0.0"
          }

          env {
            name  = "PHOENIX_PORT"
            value = tostring(var.http_port)
          }

          env {
            name  = "PHOENIX_POSTGRES_HOST"
            value = var.db_endpoint
          }

          env {
            name  = "PHOENIX_POSTGRES_PORT"
            value = tostring(var.db_port)
          }

          env {
            name  = "PHOENIX_POSTGRES_DB"
            value = var.db_name
          }

          env {
            name = "PHOENIX_POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = var.db_secret_name
                key  = "username"
              }
            }
          }

          env {
            name = "PHOENIX_POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = var.db_secret_name
                key  = "password"
              }
            }
          }

          env {
            name  = "PHOENIX_DEFAULT_RETENTION_POLICY_DAYS"
            value = tostring(var.retention_days)
          }

          env {
            name  = "PHOENIX_ENABLE_AUTH"
            value = "false"
          }

          env {
            name  = "PHOENIX_TELEMETRY_ENABLED"
            value = "false"
          }

          env {
            name  = "PHOENIX_ALLOW_EXTERNAL_RESOURCES"
            value = "false"
          }

          env {
            name  = "PHOENIX_DISABLE_MODEL_COST_AUTO_UPDATE"
            value = "true"
          }

          env {
            name  = "PHOENIX_DISABLE_AGENT_ASSISTANT"
            value = "true"
          }

          env {
            name  = "PHOENIX_ENABLE_MCP_SERVER"
            value = "false"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "1000m"
              memory = "1Gi"
            }
          }

          startup_probe {
            http_get {
              path = "/healthz"
              port = var.http_port
            }
            period_seconds    = 5
            failure_threshold = 36
          }

          readiness_probe {
            http_get {
              path = "/readyz"
              port = var.http_port
            }
            period_seconds = 10
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = var.http_port
            }
            period_seconds = 20
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "phoenix" {
  metadata {
    name      = var.service_name
    namespace = var.namespace
    labels    = local.common_labels
  }

  spec {
    type     = "ClusterIP"
    selector = local.selector_labels

    port {
      name        = "http"
      port        = var.http_port
      target_port = var.http_port
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_ingress_v1" "phoenix" {
  metadata {
    name      = var.service_name
    namespace = var.namespace
    labels    = local.common_labels
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = var.ingress_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.phoenix.metadata[0].name
              port {
                number = var.http_port
              }
            }
          }
        }
      }
    }
  }
}
