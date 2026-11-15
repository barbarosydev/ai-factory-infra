ephemeral "random_password" "master_key" {
  length  = 32
  special = false
}

resource "kubernetes_secret_v1" "master_key" {
  metadata {
    name      = "${var.release_name}-masterkey"
    namespace = var.namespace
  }

  type = "Opaque"

  data_wo = {
    masterkey = "sk-${ephemeral.random_password.master_key.result}"
  }

  data_wo_revision = var.secret_version
}

ephemeral "random_password" "agent_key" {
  for_each = var.model_routes

  length  = 32
  special = false
}

resource "kubernetes_secret_v1" "agent_key" {
  for_each = var.model_routes

  metadata {
    name      = "${var.release_name}-${each.key}-key"
    namespace = var.namespace
  }

  type = "Opaque"

  data_wo = {
    api_key = "sk-${each.key}-${ephemeral.random_password.agent_key[each.key].result}"
  }

  data_wo_revision = var.secret_version
}

resource "helm_release" "litellm" {
  name       = var.release_name
  repository = "oci://ghcr.io/berriai"
  chart      = "litellm-helm"
  version    = "1.109.1"
  namespace  = var.namespace
  wait       = true
  timeout    = 600

  values = [
    templatefile("${path.module}/values.yaml.tftpl", {
      release_name          = var.release_name
      masterkey_secret_name = kubernetes_secret_v1.master_key.metadata[0].name
      db_endpoint           = var.db_endpoint
      db_name               = var.db_name
      db_secret_name        = var.db_secret_name
      ollama_api_base       = var.ollama_api_base
      model_routes          = var.model_routes
      ingress_host          = var.ingress_host
      agent_max_budget      = var.agent_max_budget
      secret_version        = var.secret_version
    })
  ]

  depends_on = [
    kubernetes_secret_v1.master_key,
    kubernetes_secret_v1.agent_key,
  ]
}
