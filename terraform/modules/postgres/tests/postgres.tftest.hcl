# Proves the postgres module, offline with mocked providers:
# - every variable validation rejects bad input, including a PostgreSQL image
#   whose major does not match postgres_version;
# - both Helm releases pin the chart version, clean up on failure, keep five
#   revisions and wait with the module's timeouts;
# - the rendered values pin images by digest, set resources, and declare the
#   three databases and two isolated roles;
# - the role Secrets are write-only (data stays empty, data_wo_revision is set)
#   and carry the ai-factory labels.
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
  namespace           = "ai-platform"
  operator_image_tag  = "1.30.1@sha256:0000000000000000000000000000000000000000000000000000000000000000"
  postgres_image_name = "ghcr.io/cloudnative-pg/postgresql:16.9@sha256:0000000000000000000000000000000000000000000000000000000000000000"
}

run "helm_releases_pin_the_chart_and_keep_safe_release_settings" {
  command = plan

  assert {
    condition     = helm_release.cnpg_operator.version == "0.29.1" && helm_release.cnpg_cluster.version == "0.9.0"
    error_message = "Both CloudNativePG charts must be pinned to their exact default versions."
  }

  assert {
    condition     = helm_release.cnpg_operator.cleanup_on_fail && helm_release.cnpg_cluster.cleanup_on_fail
    error_message = "Both Helm releases must set cleanup_on_fail = true."
  }

  assert {
    condition     = helm_release.cnpg_operator.max_history == 5 && helm_release.cnpg_cluster.max_history == 5
    error_message = "Both Helm releases must set max_history = 5."
  }

  assert {
    condition     = helm_release.cnpg_operator.wait && helm_release.cnpg_operator.timeout == 300
    error_message = "The operator release must wait with a 300 s timeout."
  }

  assert {
    condition     = helm_release.cnpg_cluster.wait && helm_release.cnpg_cluster.timeout == 600
    error_message = "The cluster release must wait with a 600 s timeout."
  }
}

run "operator_values_pin_the_image_by_digest_and_set_resources" {
  command = plan

  assert {
    condition     = yamldecode(helm_release.cnpg_operator.values[0]).image.tag == var.operator_image_tag
    error_message = "The operator image tag must be the pinned tag plus digest."
  }

  assert {
    condition = yamldecode(helm_release.cnpg_operator.values[0]).resources == {
      requests = { cpu = "25m", memory = "64Mi" }
      limits   = { cpu = "500m", memory = "128Mi" }
    }
    error_message = "The operator must set its resource requests and limits."
  }
}

run "cluster_values_declare_databases_roles_image_and_resources" {
  command = plan

  assert {
    condition     = yamldecode(helm_release.cnpg_cluster.values[0]).cluster.imageName == var.postgres_image_name
    error_message = "The PostgreSQL image must be the pinned repository:MAJOR.MINOR@sha256 reference."
  }

  assert {
    condition     = yamldecode(helm_release.cnpg_cluster.values[0]).version.postgresql == "16"
    error_message = "version.postgresql must carry postgres_version."
  }

  assert {
    condition = yamldecode(helm_release.cnpg_cluster.values[0]).cluster.resources == {
      requests = { cpu = "100m", memory = "256Mi" }
      limits   = { cpu = "1000m", memory = "1Gi" }
    }
    error_message = "The PostgreSQL instance must set its resource requests and limits."
  }

  assert {
    condition = {
      for d in yamldecode(helm_release.cnpg_cluster.values[0]).databases : d.name => d.owner
      } == {
      temporal            = "temporal"
      temporal_visibility = "temporal"
      litellm             = "litellm"
    }
    error_message = "The cluster must declare temporal and temporal_visibility owned by temporal, and litellm owned by litellm."
  }

  assert {
    condition = {
      for r in yamldecode(helm_release.cnpg_cluster.values[0]).cluster.roles : r.name => r.passwordSecret.name
      if r.login && !r.superuser
      } == {
      temporal = "ai-postgres-temporal-credentials"
      litellm  = "ai-postgres-litellm-credentials"
    }
    error_message = "The temporal and litellm roles must be non-superuser logins reading the module's credential Secrets."
  }

  assert {
    condition = alltrue([
      for rule in [
        "host temporal,temporal_visibility temporal all scram-sha-256",
        "host all temporal all reject",
        "host litellm litellm all scram-sha-256",
        "host all litellm all reject",
      ] : contains(yamldecode(helm_release.cnpg_cluster.values[0]).cluster.postgresql.pg_hba, rule)
    ])
    error_message = "pg_hba must restrict each role to its own databases."
  }
}

run "role_secrets_are_write_only_and_labelled" {
  command = plan

  assert {
    condition     = toset(keys(kubernetes_secret_v1.db_user)) == toset(["temporal", "litellm"])
    error_message = "There must be exactly one credential Secret per role."
  }

  assert {
    condition     = alltrue([for s in kubernetes_secret_v1.db_user : s.data == null || length(s.data) == 0])
    error_message = "Credential Secrets must not use data; passwords go through data_wo."
  }

  assert {
    condition     = alltrue([for s in kubernetes_secret_v1.db_user : s.data_wo_revision == 1])
    error_message = "Credential Secrets must set data_wo_revision from password_version."
  }

  assert {
    condition = alltrue([
      for s in kubernetes_secret_v1.db_user :
      s.metadata[0].labels["app.kubernetes.io/part-of"] == "ai-factory" && s.metadata[0].labels["app.kubernetes.io/managed-by"] == "terraform"
    ])
    error_message = "Credential Secrets must carry the ai-factory part-of and managed-by labels."
  }

  assert {
    condition     = alltrue([for s in kubernetes_secret_v1.db_user : s.type == "kubernetes.io/basic-auth"])
    error_message = "Credential Secrets must be of type kubernetes.io/basic-auth."
  }
}

run "password_version_bump_changes_the_secret_revision" {
  command = plan

  variables {
    password_version = 2
  }

  assert {
    condition     = alltrue([for s in kubernetes_secret_v1.db_user : s.data_wo_revision == 2])
    error_message = "data_wo_revision must follow password_version so a bump rotates the passwords."
  }
}

run "empty_namespace_is_rejected" {
  command = plan

  variables {
    namespace = ""
  }

  expect_failures = [var.namespace]
}

run "cluster_name_that_is_not_a_dns_label_is_rejected" {
  command = plan

  variables {
    cluster_name = "AI_Postgres"
  }

  expect_failures = [var.cluster_name]
}

run "operator_image_tag_without_digest_is_rejected" {
  command = plan

  variables {
    operator_image_tag = "1.30.1"
  }

  expect_failures = [var.operator_image_tag]
}

run "unsupported_postgres_version_is_rejected" {
  command = plan

  variables {
    postgres_version    = "14"
    postgres_image_name = "ghcr.io/cloudnative-pg/postgresql:14.9@sha256:0000000000000000000000000000000000000000000000000000000000000000"
  }

  expect_failures = [var.postgres_version]
}

run "postgres_image_with_a_different_major_is_rejected" {
  command = plan

  variables {
    postgres_image_name = "ghcr.io/cloudnative-pg/postgresql:17.5@sha256:0000000000000000000000000000000000000000000000000000000000000000"
  }

  expect_failures = [var.postgres_image_name]
}

run "postgres_image_without_digest_is_rejected" {
  command = plan

  variables {
    postgres_image_name = "ghcr.io/cloudnative-pg/postgresql:16.9"
  }

  expect_failures = [var.postgres_image_name]
}

run "storage_size_that_is_not_a_quantity_is_rejected" {
  command = plan

  variables {
    storage_size = "8GB"
  }

  expect_failures = [var.storage_size]
}

run "fractional_password_version_is_rejected" {
  command = plan

  variables {
    password_version = 1.5
  }

  expect_failures = [var.password_version]
}
