# Proves the temporal module, offline with a mocked Helm provider:
# - every variable validation rejects bad input;
# - the Helm release pins the chart version, cleans up on failure, keeps five
#   revisions and waits with the module's timeout;
# - the rendered values pin all three images by digest, set resources for
#   every service, keep createDatabase false on both SQL stores, expose the
#   frontend as a LoadBalancer on 7233, and label pods part-of ai-factory.
# The module creates no Kubernetes Secret: it reads the PostgreSQL credentials
# Secret by name. Runs as plan only: no cluster, no Docker, no state.

mock_provider "helm" {}

variables {
  namespace             = "ai-platform"
  server_image_tag      = "1.29.1@sha256:0000000000000000000000000000000000000000000000000000000000000000"
  admin_tools_image_tag = "1.29.1@sha256:0000000000000000000000000000000000000000000000000000000000000000"
  ui_image_tag          = "2.40.1@sha256:0000000000000000000000000000000000000000000000000000000000000000"
  db_endpoint           = "ai-postgres-cluster-rw"
  db_secret_name        = "ai-postgres-temporal-credentials"
}

run "helm_release_pins_the_chart_and_keeps_safe_release_settings" {
  command = plan

  assert {
    condition     = helm_release.temporal.version == "1.8.0"
    error_message = "The Temporal chart must be pinned to its exact default version."
  }

  assert {
    condition     = helm_release.temporal.cleanup_on_fail && helm_release.temporal.max_history == 5
    error_message = "The Temporal release must set cleanup_on_fail = true and max_history = 5."
  }

  assert {
    condition     = helm_release.temporal.wait && helm_release.temporal.timeout == 900
    error_message = "The Temporal release must wait with a 900 s timeout."
  }
}

run "values_pin_every_image_by_digest" {
  command = plan

  assert {
    condition     = yamldecode(helm_release.temporal.values[0]).server.image.tag == var.server_image_tag
    error_message = "The server image tag must be the pinned tag plus digest."
  }

  assert {
    condition     = yamldecode(helm_release.temporal.values[0]).admintools.image.tag == var.admin_tools_image_tag
    error_message = "The admin-tools image tag must be the pinned tag plus digest."
  }

  assert {
    condition     = yamldecode(helm_release.temporal.values[0]).web.image.tag == var.ui_image_tag
    error_message = "The UI image tag must be the pinned tag plus digest."
  }
}

run "values_set_resources_for_every_service" {
  command = plan

  assert {
    condition = alltrue([
      for svc in ["frontend", "history", "matching", "worker"] :
      can(yamldecode(helm_release.temporal.values[0]).server[svc].resources.requests.memory) &&
      can(yamldecode(helm_release.temporal.values[0]).server[svc].resources.limits.memory) &&
      can(yamldecode(helm_release.temporal.values[0]).server[svc].resources.limits.cpu)
    ])
    error_message = "Every Temporal server service must set memory requests and CPU and memory limits."
  }

  assert {
    condition = yamldecode(helm_release.temporal.values[0]).server.history.resources == {
      requests = { cpu = "50m", memory = "192Mi" }
      limits   = { cpu = "1000m", memory = "512Mi" }
    }
    error_message = "The history service must keep its measured resource requests and limits."
  }

  assert {
    condition = yamldecode(helm_release.temporal.values[0]).web.resources == {
      requests = { cpu = "10m", memory = "32Mi" }
      limits   = { cpu = "250m", memory = "128Mi" }
    }
    error_message = "The Web UI must set its resource requests and limits."
  }

  assert {
    condition = alltrue([
      for store in ["default", "visibility"] :
      yamldecode(helm_release.temporal.values[0]).server.config.persistence.datastores[store].sql.maxConns <= 10 &&
      yamldecode(helm_release.temporal.values[0]).server.config.persistence.datastores[store].sql.maxIdleConns <= 4
    ])
    error_message = "Temporal SQL pools must stay bounded to avoid oversubscribing PostgreSQL max_connections."
  }
}

run "values_keep_sql_setup_and_frontend_exposure_correct" {
  command = plan

  assert {
    condition = alltrue([
      for store in ["default", "visibility"] :
      yamldecode(helm_release.temporal.values[0]).server.config.persistence.datastores[store].sql.createDatabase == false
    ])
    error_message = "Both SQL datastores must set createDatabase: false (CloudNativePG creates the databases)."
  }

  assert {
    condition = {
      for store in ["default", "visibility"] :
      store => yamldecode(helm_release.temporal.values[0]).server.config.persistence.datastores[store].sql.databaseName
      } == {
      default    = "temporal"
      visibility = "temporal_visibility"
    }
    error_message = "The SQL datastores must use the temporal and temporal_visibility databases."
  }

  assert {
    condition = alltrue([
      for store in ["default", "visibility"] :
      yamldecode(helm_release.temporal.values[0]).server.config.persistence.datastores[store].sql.existingSecret == var.db_secret_name
    ])
    error_message = "Both SQL datastores must read the password from the credentials Secret by name."
  }

  assert {
    condition = yamldecode(helm_release.temporal.values[0]).server.frontend.service == {
      type = "LoadBalancer"
      port = 7233
    }
    error_message = "The frontend must be a LoadBalancer Service on port 7233."
  }
}

run "values_label_resources_part_of_ai_factory" {
  command = plan

  assert {
    condition = alltrue([
      yamldecode(helm_release.temporal.values[0]).additionalLabels["app.kubernetes.io/part-of"] == "ai-factory",
      yamldecode(helm_release.temporal.values[0]).server.podLabels["app.kubernetes.io/part-of"] == "ai-factory",
      yamldecode(helm_release.temporal.values[0]).web.podLabels["app.kubernetes.io/part-of"] == "ai-factory",
      yamldecode(helm_release.temporal.values[0]).schema.podLabels["app.kubernetes.io/part-of"] == "ai-factory",
    ])
    error_message = "Chart resources and pods must carry app.kubernetes.io/part-of = ai-factory."
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
    release_name = "Temporal-"
  }

  expect_failures = [var.release_name]
}

run "empty_chart_version_is_rejected" {
  command = plan

  variables {
    chart_version = ""
  }

  expect_failures = [var.chart_version]
}

run "image_tags_without_digest_are_rejected" {
  command = plan

  variables {
    server_image_tag      = "1.29.1"
    admin_tools_image_tag = "latest"
    ui_image_tag          = "2.40.1@sha256:abc"
  }

  expect_failures = [
    var.server_image_tag,
    var.admin_tools_image_tag,
    var.ui_image_tag,
  ]
}

run "empty_database_settings_are_rejected" {
  command = plan

  variables {
    db_endpoint        = ""
    default_db_name    = ""
    visibility_db_name = ""
    db_user            = ""
    db_secret_name     = ""
  }

  expect_failures = [
    var.db_endpoint,
    var.default_db_name,
    var.visibility_db_name,
    var.db_user,
    var.db_secret_name,
  ]
}

run "ports_out_of_range_are_rejected" {
  command = plan

  variables {
    db_port   = 0
    grpc_port = 65536
  }

  expect_failures = [
    var.db_port,
    var.grpc_port,
  ]
}

run "retention_that_is_not_hours_or_days_is_rejected" {
  command = plan

  variables {
    default_namespace_retention = "3 days"
  }

  expect_failures = [var.default_namespace_retention]
}

run "empty_ingress_host_is_rejected" {
  command = plan

  variables {
    ingress_host = ""
  }

  expect_failures = [var.ingress_host]
}
