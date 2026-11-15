output "namespace" {
  description = "Kubernetes namespace hosting the AI platform stack."
  value       = kubernetes_namespace_v1.ai_platform.metadata[0].name
}

output "postgres_cluster_name" {
  description = "Name of the CloudNativePG PostgreSQL cluster."
  value       = module.postgres.cluster_name
}

output "postgres_rw_service" {
  description = "Kubernetes Service name for read-write PostgreSQL connections."
  value       = module.postgres.rw_service_name
}

output "postgres_databases" {
  description = "Provisioned PostgreSQL databases."
  value       = module.postgres.databases
}

output "postgres_user_secrets" {
  description = "Kubernetes Secret names holding the PostgreSQL user credentials."
  value       = module.postgres.user_secret_names
}
