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

# atomic is intentionally false: CRDs and operator-managed Cluster resources
# reconcile asynchronously, and scripts/terraform.sh waits on condition=Ready.
resource "helm_release" "cnpg_operator" {
  name            = "cnpg"
  repository      = "https://cloudnative-pg.github.io/charts"
  chart           = "cloudnative-pg"
  version         = var.operator_chart_version
  namespace       = var.namespace
  wait            = true
  timeout         = 300
  cleanup_on_fail = true
  max_history     = 5

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
      "app.kubernetes.io/part-of"    = "ai-factory"
      "app.kubernetes.io/component"  = "postgres"
      "app.kubernetes.io/managed-by" = "terraform"
      "cnpg.io/reload"               = "true"
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
  name            = var.cluster_name
  repository      = "https://cloudnative-pg.github.io/charts"
  chart           = "cluster"
  version         = var.cluster_chart_version
  namespace       = var.namespace
  wait            = true
  timeout         = 600
  cleanup_on_fail = true
  max_history     = 5

  values = [
    templatefile("${path.module}/values.yaml.tftpl", {
      cluster_name        = var.cluster_name
      postgres_version    = var.postgres_version
      postgres_image_name = var.postgres_image_name
      storage_size        = var.storage_size
    })
  ]

  depends_on = [
    helm_release.cnpg_operator,
    kubernetes_secret_v1.db_user,
  ]
}
