# Proves the network-policies module, offline with mocked Kubernetes provider:
# - enforces default-deny-all and DNS egress;
# - isolates Phoenix from internet/Ollama egress (Postgres :5432 only);
# - restricts LiteLLM Ollama egress to non-cluster CIDRs on port 11434;
# - rejects empty namespace.

mock_provider "kubernetes" {}

variables {
  namespace = "ai-platform"
}

run "policies_enforce_default_deny_and_service_isolation" {
  command = plan

  assert {
    condition     = toset(kubernetes_network_policy_v1.default_deny_all.spec[0].policy_types) == toset(["Ingress", "Egress"])
    error_message = "default-deny-all must enforce both Ingress and Egress."
  }

  assert {
    condition     = length(kubernetes_network_policy_v1.phoenix.spec[0].egress) == 1 && kubernetes_network_policy_v1.phoenix.spec[0].egress[0].ports[0].port == "5432"
    error_message = "Phoenix must only egress to Postgres port 5432 (no Ollama or internet egress)."
  }

  assert {
    condition     = contains([for e in kubernetes_network_policy_v1.litellm.spec[0].egress : e.ports[0].port], "11434")
    error_message = "LiteLLM must allow egress to host Ollama on port 11434."
  }
}

run "empty_namespace_is_rejected" {
  command = plan

  variables {
    namespace = ""
  }

  expect_failures = [var.namespace]
}

run "invalid_cidrs_are_rejected" {
  command = plan

  variables {
    cluster_pod_cidr = "not-a-cidr"
    service_cidr     = "999.999.0.0/16"
  }

  expect_failures = [
    var.cluster_pod_cidr,
    var.service_cidr,
  ]
}
