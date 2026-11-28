ephemeral "random_password" "master_key" {
  length  = 32
  special = false
}

resource "kubernetes_secret_v1" "master_key" {
  metadata {
    name      = "${var.release_name}-masterkey"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/part-of"    = "ai-factory"
      "app.kubernetes.io/component"  = "litellm"
      "app.kubernetes.io/managed-by" = "terraform"
    }
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
    labels = {
      "app.kubernetes.io/part-of"    = "ai-factory"
      "app.kubernetes.io/component"  = "litellm"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  type = "Opaque"

  data_wo = {
    api_key = "sk-${each.key}-${ephemeral.random_password.agent_key[each.key].result}"
  }

  data_wo_revision = var.secret_version
}

locals {
  bootstrap_hash = substr(
    sha256(jsonencode({
      image_tag        = var.image_tag
      model_routes     = var.model_routes
      agent_max_budget = var.agent_max_budget
    })),
    0,
    8,
  )
}

# atomic is intentionally false: the migration and virtual-key bootstrap Jobs
# run alongside the Deployment without Helm hooks so a slow first image pull
# does not roll back the release; scripts/terraform.sh waits on rollout and Jobs.
resource "helm_release" "litellm" {
  name            = var.release_name
  repository      = "oci://ghcr.io/berriai"
  chart           = "litellm-helm"
  version         = var.chart_version
  namespace       = var.namespace
  wait            = true
  timeout         = 600
  cleanup_on_fail = true
  max_history     = 5

  values = [
    templatefile("${path.module}/values.yaml.tftpl", {
      release_name                = var.release_name
      image_tag                   = var.image_tag
      bootstrap_hash              = local.bootstrap_hash
      masterkey_secret_name       = kubernetes_secret_v1.master_key.metadata[0].name
      db_endpoint                 = var.db_endpoint
      db_name                     = var.db_name
      db_secret_name              = var.db_secret_name
      ollama_api_base             = var.ollama_api_base
      model_routes                = var.model_routes
      ingress_host                = var.ingress_host
      agent_max_budget            = var.agent_max_budget
      store_prompts_in_spend_logs = var.store_prompts_in_spend_logs
      spend_logs_retention        = var.spend_logs_retention
      input_cost_per_token        = var.input_cost_per_token
      output_cost_per_token       = var.output_cost_per_token
      secret_version              = var.secret_version
    })
  ]

  depends_on = [
    kubernetes_secret_v1.master_key,
    kubernetes_secret_v1.agent_key,
  ]
}
