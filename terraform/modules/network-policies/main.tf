locals {
  common_labels = {
    "app.kubernetes.io/part-of"    = "ai-factory"
    "app.kubernetes.io/component"  = "network-policy"
    "app.kubernetes.io/managed-by" = "terraform"
  }
}

resource "kubernetes_network_policy_v1" "default_deny_all" {
  metadata {
    name      = "default-deny-all"
    namespace = var.namespace
    labels    = local.common_labels
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }
}

resource "kubernetes_network_policy_v1" "allow_dns_egress" {
  metadata {
    name      = "allow-dns-egress"
    namespace = var.namespace
    labels    = local.common_labels
  }

  spec {
    pod_selector {}
    policy_types = ["Egress"]

    egress {
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
        pod_selector {
          match_labels = {
            "k8s-app" = "kube-dns"
          }
        }
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "postgres" {
  metadata {
    name      = "postgres-least-privilege"
    namespace = var.namespace
    labels    = local.common_labels
  }

  spec {
    pod_selector {
      match_labels = {
        "cnpg.io/cluster" = "ai-postgres-cluster"
      }
    }

    policy_types = ["Ingress", "Egress"]

    ingress {
      ports {
        port     = "5432"
        protocol = "TCP"
      }
      ports {
        port     = "8000"
        protocol = "TCP"
      }
      from {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name" = "cloudnative-pg"
          }
        }
      }
      from {
        pod_selector {
          match_labels = {
            "cnpg.io/cluster" = "ai-postgres-cluster"
          }
        }
      }
    }

    ingress {
      ports {
        port     = "5432"
        protocol = "TCP"
      }
      from {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name" = "litellm"
          }
        }
      }
      from {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name" = "temporal"
          }
        }
      }
      from {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name" = "phoenix"
          }
        }
      }
      from {
        pod_selector {
          match_expressions {
            key      = "batch.kubernetes.io/job-name"
            operator = "Exists"
          }
        }
      }
      from {
        pod_selector {
          match_labels = {
            "ai-factory/smoke-probe" = "true"
          }
        }
      }
      from {
        pod_selector {
          match_labels = {
            "ai-factory/smoke-probe" = "true"
          }
        }
      }
    }

    egress {
      ports {
        port     = "5432"
        protocol = "TCP"
      }
      ports {
        port     = "8000"
        protocol = "TCP"
      }
      to {
        pod_selector {
          match_labels = {
            "cnpg.io/cluster" = "ai-postgres-cluster"
          }
        }
      }
    }

    egress {
      ports {
        port     = "443"
        protocol = "TCP"
      }
      ports {
        port     = "6443"
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "cnpg_operator" {
  metadata {
    name      = "cnpg-operator-least-privilege"
    namespace = var.namespace
    labels    = local.common_labels
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = "cloudnative-pg"
      }
    }

    policy_types = ["Ingress", "Egress"]

    ingress {
      ports {
        port     = "9443"
        protocol = "TCP"
      }
    }

    egress {
      ports {
        port     = "5432"
        protocol = "TCP"
      }
      ports {
        port     = "8000"
        protocol = "TCP"
      }
      to {
        pod_selector {
          match_labels = {
            "cnpg.io/cluster" = "ai-postgres-cluster"
          }
        }
      }
    }

    egress {
      ports {
        port     = "443"
        protocol = "TCP"
      }
      ports {
        port     = "6443"
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "litellm" {
  metadata {
    name      = "litellm-least-privilege"
    namespace = var.namespace
    labels    = local.common_labels
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = "litellm"
      }
    }

    policy_types = ["Ingress", "Egress"]

    ingress {
      ports {
        port     = "4000"
        protocol = "TCP"
      }
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name" = "traefik"
          }
        }
      }
      from {
        pod_selector {
          match_expressions {
            key      = "batch.kubernetes.io/job-name"
            operator = "Exists"
          }
        }
      }
      from {
        pod_selector {
          match_labels = {
            "ai-factory/smoke-probe" = "true"
          }
        }
      }
    }

    egress {
      ports {
        port     = "5432"
        protocol = "TCP"
      }
      to {
        pod_selector {
          match_labels = {
            "cnpg.io/cluster" = "ai-postgres-cluster"
          }
        }
      }
    }

    egress {
      ports {
        port     = "11434"
        protocol = "TCP"
      }
      to {
        ip_block {
          cidr   = "0.0.0.0/0"
          except = [var.cluster_pod_cidr, var.service_cidr]
        }
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "temporal" {
  metadata {
    name      = "temporal-least-privilege"
    namespace = var.namespace
    labels    = local.common_labels
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = "temporal"
      }
    }

    policy_types = ["Ingress", "Egress"]

    # Temporal Web UI via Traefik ingress
    ingress {
      ports {
        port     = "8080"
        protocol = "TCP"
      }
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name" = "traefik"
          }
        }
      }
    }

    # Temporal gRPC frontend via k3s ServiceLB (:7233) & Mac host workers
    ingress {
      ports {
        port     = "7233"
        protocol = "TCP"
      }
    }

    # Intra-Temporal gRPC & Ringpop membership mesh
    ingress {
      dynamic "ports" {
        for_each = ["7233", "7234", "7235", "7239", "6933", "6934", "6935", "6939"]
        content {
          port     = ports.value
          protocol = "TCP"
        }
      }
      from {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name" = "temporal"
          }
        }
      }
      from {
        pod_selector {
          match_expressions {
            key      = "batch.kubernetes.io/job-name"
            operator = "Exists"
          }
        }
      }
      from {
        pod_selector {
          match_labels = {
            "ai-factory/smoke-probe" = "true"
          }
        }
      }
    }

    egress {
      ports {
        port     = "5432"
        protocol = "TCP"
      }
      to {
        pod_selector {
          match_labels = {
            "cnpg.io/cluster" = "ai-postgres-cluster"
          }
        }
      }
    }

    egress {
      dynamic "ports" {
        for_each = ["7233", "7234", "7235", "7239", "6933", "6934", "6935", "6939"]
        content {
          port     = ports.value
          protocol = "TCP"
        }
      }
      to {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name" = "temporal"
          }
        }
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "phoenix" {
  metadata {
    name      = "phoenix-least-privilege"
    namespace = var.namespace
    labels    = local.common_labels
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = "phoenix"
      }
    }

    policy_types = ["Ingress", "Egress"]

    ingress {
      ports {
        port     = "6006"
        protocol = "TCP"
      }
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name" = "traefik"
          }
        }
      }
    }

    egress {
      ports {
        port     = "5432"
        protocol = "TCP"
      }
      to {
        pod_selector {
          match_labels = {
            "cnpg.io/cluster" = "ai-postgres-cluster"
          }
        }
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "jobs_and_probes" {
  metadata {
    name      = "jobs-and-probes-egress"
    namespace = var.namespace
    labels    = local.common_labels
  }

  spec {
    pod_selector {
      match_expressions {
        key      = "batch.kubernetes.io/job-name"
        operator = "Exists"
      }
    }

    policy_types = ["Egress"]

    egress {
      ports {
        port     = "5432"
        protocol = "TCP"
      }
      to {
        pod_selector {
          match_labels = {
            "cnpg.io/cluster" = "ai-postgres-cluster"
          }
        }
      }
    }

    egress {
      ports {
        port     = "4000"
        protocol = "TCP"
      }
      to {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name" = "litellm"
          }
        }
      }
    }

    egress {
      ports {
        port     = "7233"
        protocol = "TCP"
      }
      to {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name" = "temporal"
          }
        }
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "smoke_probe" {
  metadata {
    name      = "smoke-probe-egress"
    namespace = var.namespace
    labels    = local.common_labels
  }

  spec {
    pod_selector {
      match_labels = {
        "ai-factory/smoke-probe" = "true"
      }
    }

    policy_types = ["Egress"]

    egress {
      ports {
        port     = "5432"
        protocol = "TCP"
      }
      to {
        pod_selector {
          match_labels = {
            "cnpg.io/cluster" = "ai-postgres-cluster"
          }
        }
      }
    }

    egress {
      ports {
        port     = "4000"
        protocol = "TCP"
      }
      to {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name" = "litellm"
          }
        }
      }
    }
  }
}
