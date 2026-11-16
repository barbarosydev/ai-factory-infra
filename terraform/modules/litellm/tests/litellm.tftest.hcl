# Proves the litellm module, offline with mocked providers:
# - every variable validation rejects bad input, including empty model routes;
# - the Helm release pins the chart version, cleans up on failure, keeps five
#   revisions and waits with the module's timeout;
# - the rendered values pin the image by digest (proxy and bootstrap Job), set
#   resources, and route each agent name to its Ollama model through the
#   ollama Service;
# - the master key and per-agent key Secrets are write-only (data stays
#   empty, data_wo_revision follows secret_version) and carry the ai-factory
#   labels.
# Runs as plan only: no cluster, no Docker, no state. Digests are fake (zeros).

mock_provider "helm" {}
# data on kubernetes_secret_v1 is optional and computed, so it is unknown at
# plan; generating mock values during plan makes it known (empty unless set).
mock_provider "kubernetes" {
  mock_resource "kubernetes_secret_v1" {
    override_during = plan
    defaults        = {}
  }
}
mock_provider "random" {}

variables {
  namespace       = "ai-platform"
  image_tag       = "1.79.0@sha256:0000000000000000000000000000000000000000000000000000000000000000"
  db_endpoint     = "ai-postgres-cluster-rw"
  db_secret_name  = "ai-postgres-litellm-credentials"
  ollama_api_base = "http://ollama:11434"
  model_routes = {
    pm-agent  = "gemma4:12b"
    dev-agent = "gemma4:e4b"
    sec-agent = "gemma4:e4b"
  }
}

run "helm_release_pins_the_chart_and_keeps_safe_release_settings" {
  command = plan

  assert {
    condition     = helm_release.litellm.version == "1.109.1"
    error_message = "The LiteLLM chart must be pinned to its exact default version."
  }

  assert {
    condition     = helm_release.litellm.cleanup_on_fail && helm_release.litellm.max_history == 5
    error_message = "The LiteLLM release must set cleanup_on_fail = true and max_history = 5."
  }

  assert {
    condition     = helm_release.litellm.wait && helm_release.litellm.timeout == 600
    error_message = "The LiteLLM release must wait with a 600 s timeout."
  }
}

run "values_pin_the_image_by_digest_and_set_resources" {
  command = plan

  assert {
    condition     = yamldecode(helm_release.litellm.values[0]).image.tag == var.image_tag
    error_message = "The LiteLLM image tag must be the pinned tag plus digest."
  }

  assert {
    condition     = yamldecode(helm_release.litellm.values[0]).extraResources[0].spec.template.spec.containers[0].image == "ghcr.io/berriai/litellm:${var.image_tag}"
    error_message = "The bootstrap-keys Job must run the same pinned LiteLLM image."
  }

  assert {
    condition = yamldecode(helm_release.litellm.values[0]).resources == {
      requests = { cpu = "200m", memory = "512Mi" }
      limits   = { cpu = "1000m", memory = "2Gi" }
    }
    error_message = "LiteLLM must set its resource requests and limits."
  }

  assert {
    condition     = yamldecode(helm_release.litellm.values[0]).masterkeySecretName == "litellm-masterkey" && yamldecode(helm_release.litellm.values[0]).db.secret.name == var.db_secret_name
    error_message = "LiteLLM must read its master key and database credentials from Secrets by name."
  }
}

run "values_route_each_agent_to_its_ollama_model" {
  command = plan

  assert {
    condition = {
      for m in yamldecode(helm_release.litellm.values[0]).proxy_config.model_list : m.model_name => m.litellm_params.model
      } == {
      pm-agent  = "ollama/gemma4:12b"
      dev-agent = "ollama/gemma4:e4b"
      sec-agent = "ollama/gemma4:e4b"
    }
    error_message = "Each agent route must map to its Ollama model."
  }

  assert {
    condition     = alltrue([for m in yamldecode(helm_release.litellm.values[0]).proxy_config.model_list : m.litellm_params.api_base == "http://ollama:11434"])
    error_message = "Every route must reach Ollama only through the ollama Service."
  }
}

run "key_secrets_are_write_only_and_labelled" {
  command = plan

  assert {
    condition     = toset(keys(kubernetes_secret_v1.agent_key)) == toset(["pm-agent", "dev-agent", "sec-agent"])
    error_message = "There must be exactly one virtual key Secret per agent route."
  }

  assert {
    condition = alltrue([
      for s in concat([kubernetes_secret_v1.master_key], values(kubernetes_secret_v1.agent_key)) :
      s.data == null || length(s.data) == 0
    ])
    error_message = "Key Secrets must not use data; keys go through data_wo."
  }

  assert {
    condition = alltrue([
      for s in concat([kubernetes_secret_v1.master_key], values(kubernetes_secret_v1.agent_key)) :
      s.data_wo_revision == var.secret_version
    ])
    error_message = "Key Secrets must set data_wo_revision from secret_version."
  }

  assert {
    condition = alltrue([
      for s in concat([kubernetes_secret_v1.master_key], values(kubernetes_secret_v1.agent_key)) :
      s.metadata[0].labels["app.kubernetes.io/part-of"] == "ai-factory" && s.metadata[0].labels["app.kubernetes.io/managed-by"] == "terraform"
    ])
    error_message = "Key Secrets must carry the ai-factory part-of and managed-by labels."
  }
}

run "secret_version_bump_changes_every_key_revision" {
  command = plan

  variables {
    secret_version = 2
  }

  assert {
    condition = alltrue([
      for s in concat([kubernetes_secret_v1.master_key], values(kubernetes_secret_v1.agent_key)) :
      s.data_wo_revision == 2
    ])
    error_message = "data_wo_revision must follow secret_version so a bump rotates every key."
  }

  assert {
    condition     = yamldecode(helm_release.litellm.values[0]).extraResources[0].metadata.name == "litellm-bootstrap-keys-v2"
    error_message = "A secret_version bump must rename the bootstrap-keys Job so it runs again."
  }
}

run "empty_namespace_is_rejected" {
  command = plan

  variables {
    namespace = ""
  }

  expect_failures = [var.namespace]
}

run "release_name_that_is_not_a_dns_label_is_rejected" {
  command = plan

  variables {
    release_name = "LiteLLM"
  }

  expect_failures = [var.release_name]
}

run "image_tag_without_digest_is_rejected" {
  command = plan

  variables {
    image_tag = "1.79.0"
  }

  expect_failures = [var.image_tag]
}

run "empty_db_endpoint_is_rejected" {
  command = plan

  variables {
    db_endpoint = " "
  }

  expect_failures = [var.db_endpoint]
}

run "empty_db_name_is_rejected" {
  command = plan

  variables {
    db_name = ""
  }

  expect_failures = [var.db_name]
}

run "empty_db_secret_name_is_rejected" {
  command = plan

  variables {
    db_secret_name = ""
  }

  expect_failures = [var.db_secret_name]
}

run "ollama_api_base_without_scheme_is_rejected" {
  command = plan

  variables {
    ollama_api_base = "ollama:11434"
  }

  expect_failures = [var.ollama_api_base]
}

run "empty_model_routes_are_rejected" {
  command = plan

  variables {
    model_routes = {}
  }

  expect_failures = [var.model_routes]
}

run "model_route_with_empty_model_is_rejected" {
  command = plan

  variables {
    model_routes = {
      pm-agent = " "
    }
  }

  expect_failures = [var.model_routes]
}

run "empty_ingress_host_is_rejected" {
  command = plan

  variables {
    ingress_host = ""
  }

  expect_failures = [var.ingress_host]
}

run "zero_agent_budget_is_rejected" {
  command = plan

  variables {
    agent_max_budget = 0
  }

  expect_failures = [var.agent_max_budget]
}

run "zero_secret_version_is_rejected" {
  command = plan

  variables {
    secret_version = 0
  }

  expect_failures = [var.secret_version]
}
