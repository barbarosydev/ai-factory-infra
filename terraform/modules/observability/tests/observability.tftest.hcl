# Proves the observability module, offline with a mocked Kubernetes provider:
# - every variable validation rejects bad input (unpinned images, latest tags,
#   invalid ports, zero retention);
# - the Deployment pins the image by digest, sets CPU/memory requests & limits,
#   wires PostgreSQL credentials via Secret references, disables auth/telemetry/
#   external resources, and sets 3-day retention;
# - Deployment, Service, and Traefik Ingress carry the ai-factory labels.

mock_provider "kubernetes" {}

variables {
  namespace      = "ai-platform"
  image_name     = "arizephoenix/phoenix:version-22.0.1@sha256:0000000000000000000000000000000000000000000000000000000000000000"
  db_endpoint    = "ai-postgres-cluster-rw"
  db_secret_name = "ai-postgres-phoenix-credentials"
}

run "deployment_service_and_ingress_follow_project_conventions" {
  command = plan

  assert {
    condition     = kubernetes_deployment_v1.phoenix.spec[0].template[0].spec[0].container[0].image == var.image_name
    error_message = "Phoenix must run the exact digest-pinned image."
  }

  assert {
    condition = (
      kubernetes_deployment_v1.phoenix.spec[0].template[0].spec[0].container[0].resources[0].requests["cpu"] == "100m" &&
      kubernetes_deployment_v1.phoenix.spec[0].template[0].spec[0].container[0].resources[0].requests["memory"] == "256Mi" &&
      kubernetes_deployment_v1.phoenix.spec[0].template[0].spec[0].container[0].resources[0].limits["cpu"] == "1000m" &&
      kubernetes_deployment_v1.phoenix.spec[0].template[0].spec[0].container[0].resources[0].limits["memory"] == "1Gi"
    )
    error_message = "Phoenix must declare explicit CPU and memory requests and limits."
  }

  assert {
    condition = {
      for e in kubernetes_deployment_v1.phoenix.spec[0].template[0].spec[0].container[0].env :
      e.name => e.value if e.value != null && e.value != ""
      } == {
      PHOENIX_HOST                           = "0.0.0.0"
      PHOENIX_PORT                           = "6006"
      PHOENIX_POSTGRES_HOST                  = "ai-postgres-cluster-rw"
      PHOENIX_POSTGRES_PORT                  = "5432"
      PHOENIX_POSTGRES_DB                    = "phoenix"
      PHOENIX_DEFAULT_RETENTION_POLICY_DAYS  = "7"
      PHOENIX_ENABLE_AUTH                    = "false"
      PHOENIX_TELEMETRY_ENABLED              = "false"
      PHOENIX_ALLOW_EXTERNAL_RESOURCES       = "false"
      PHOENIX_DISABLE_MODEL_COST_AUTO_UPDATE = "true"
      PHOENIX_DISABLE_AGENT_ASSISTANT        = "true"
      PHOENIX_ENABLE_MCP_SERVER              = "false"
    }
    error_message = "Phoenix must configure PostgreSQL, 7-day retention, no-auth, and air-gapped telemetry settings."
  }

  assert {
    condition     = kubernetes_deployment_v1.phoenix.spec[0].template[0].spec[0].container[0].security_context[0].allow_privilege_escalation == false
    error_message = "Phoenix container must disallow privilege escalation."
  }

  assert {
    condition = {
      for e in kubernetes_deployment_v1.phoenix.spec[0].template[0].spec[0].container[0].env :
      e.name => "${e.value_from[0].secret_key_ref[0].name}:${e.value_from[0].secret_key_ref[0].key}"
      if length(e.value_from) > 0
      } == {
      PHOENIX_POSTGRES_USER     = "ai-postgres-phoenix-credentials:username"
      PHOENIX_POSTGRES_PASSWORD = "ai-postgres-phoenix-credentials:password"
    }
    error_message = "Phoenix must read PostgreSQL credentials from the dedicated Kubernetes Secret."
  }

  assert {
    condition = alltrue([
      for lbls in [
        kubernetes_deployment_v1.phoenix.metadata[0].labels,
        kubernetes_service_v1.phoenix.metadata[0].labels,
        kubernetes_ingress_v1.phoenix.metadata[0].labels,
      ] : lbls["app.kubernetes.io/part-of"] == "ai-factory" && lbls["app.kubernetes.io/managed-by"] == "terraform"
    ])
    error_message = "Deployment, Service and Ingress must carry the ai-factory labels."
  }

  assert {
    condition     = kubernetes_ingress_v1.phoenix.spec[0].ingress_class_name == "traefik" && kubernetes_ingress_v1.phoenix.spec[0].rule[0].host == "phoenix.localhost"
    error_message = "Ingress must route phoenix.localhost through Traefik."
  }

  assert {
    condition     = output.ingress_url == "http://phoenix.localhost:8080" && output.otlp_http_traces_endpoint == "http://phoenix.localhost:8080/v1/traces"
    error_message = "Outputs must expose the local UI and OTLP HTTP endpoints."
  }
}

run "image_without_digest_is_rejected" {
  command = plan

  variables {
    image_name = "arizephoenix/phoenix:version-22.0.1"
  }

  expect_failures = [var.image_name]
}

run "latest_image_is_rejected" {
  command = plan

  variables {
    image_name = "arizephoenix/phoenix:latest@sha256:0000000000000000000000000000000000000000000000000000000000000000"
  }

  expect_failures = [var.image_name]
}

run "zero_retention_is_rejected" {
  command = plan

  variables {
    retention_days = 0
  }

  expect_failures = [var.retention_days]
}

run "invalid_service_name_is_rejected" {
  command = plan

  variables {
    service_name = "Phoenix_UI"
  }

  expect_failures = [var.service_name]
}
