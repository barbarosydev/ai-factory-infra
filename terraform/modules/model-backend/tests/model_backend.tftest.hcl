# Proves the model-backend module, offline with a mocked Kubernetes provider:
# - every variable validation rejects bad input;
# - the ollama Service is an ExternalName to the Mac host on the Ollama port;
# - the Service carries the ai-factory part-of and managed-by labels.
# Runs as plan only: no cluster, no Docker, no state.

mock_provider "kubernetes" {}

variables {
  namespace = "ai-platform"
}

run "service_points_at_the_mac_host_and_carries_the_project_labels" {
  command = plan

  assert {
    condition     = kubernetes_service_v1.ollama.spec[0].type == "ExternalName"
    error_message = "The ollama Service must be of type ExternalName."
  }

  assert {
    condition     = kubernetes_service_v1.ollama.spec[0].external_name == "host.k3d.internal"
    error_message = "The ollama Service must point at host.k3d.internal by default."
  }

  assert {
    condition     = kubernetes_service_v1.ollama.spec[0].port[0].port == 11434 && kubernetes_service_v1.ollama.spec[0].port[0].target_port == "11434"
    error_message = "The ollama Service must expose and target port 11434 by default."
  }

  assert {
    condition     = kubernetes_service_v1.ollama.metadata[0].namespace == "ai-platform" && kubernetes_service_v1.ollama.metadata[0].name == "ollama"
    error_message = "The ollama Service must be named ollama in the given namespace."
  }

  assert {
    condition     = kubernetes_service_v1.ollama.metadata[0].labels["app.kubernetes.io/part-of"] == "ai-factory"
    error_message = "The ollama Service must carry app.kubernetes.io/part-of = ai-factory."
  }

  assert {
    condition     = kubernetes_service_v1.ollama.metadata[0].labels["app.kubernetes.io/managed-by"] == "terraform"
    error_message = "The ollama Service must carry app.kubernetes.io/managed-by = terraform."
  }

  assert {
    condition     = output.api_base == "http://ollama:11434"
    error_message = "api_base must be the in-cluster URL of the ollama Service."
  }
}

run "empty_namespace_is_rejected" {
  command = plan

  variables {
    namespace = "  "
  }

  expect_failures = [var.namespace]
}

run "service_name_that_is_not_a_dns_label_is_rejected" {
  command = plan

  variables {
    service_name = "Ollama_Service"
  }

  expect_failures = [var.service_name]
}

run "empty_host_address_is_rejected" {
  command = plan

  variables {
    host_address = ""
  }

  expect_failures = [var.host_address]
}

run "port_out_of_range_is_rejected" {
  command = plan

  variables {
    port = 70000
  }

  expect_failures = [var.port]
}
