locals {
  db_users = {
    temporal = {
      databases = ["temporal", "temporal_visibility"]
    }
    litellm = {
      databases = ["litellm"]
    }
  }
}

resource "helm_release" "cnpg_operator" {
  name       = "cnpg"
  repository = "https://cloudnative-pg.github.io/charts"
  chart      = "cloudnative-pg"
  version    = "0.29.1"
  namespace  = var.namespace
  wait       = true
  timeout    = 300

  values = [
    templatefile("${path.module}/operator-values.yaml.tftpl", {})
  ]
}

ephemeral "random_password" "db_user" {
  for_each = local.db_users

  length  = 32
  special = false
}

resource "kubernetes_secret_v1" "db_user" {
  for_each = local.db_users

  metadata {
    name      = "${var.cluster_name}-${each.key}-credentials"
    namespace = var.namespace
    labels = {
      "cnpg.io/reload" = "true"
    }
  }

  type = "kubernetes.io/basic-auth"

  data_wo = {
    username = each.key
    password = ephemeral.random_password.db_user[each.key].result
  }

  data_wo_revision = var.password_version
}

resource "helm_release" "cnpg_cluster" {
  name       = var.cluster_name
  repository = "https://cloudnative-pg.github.io/charts"
  chart      = "cluster"
  version    = "0.9.0"
  namespace  = var.namespace
  wait       = true
  timeout    = 600

  values = [
    templatefile("${path.module}/values.yaml.tftpl", {
      cluster_name     = var.cluster_name
      postgres_version = var.postgres_version
      storage_size     = var.storage_size
    })
  ]

  depends_on = [
    helm_release.cnpg_operator,
    kubernetes_secret_v1.db_user,
  ]
}
