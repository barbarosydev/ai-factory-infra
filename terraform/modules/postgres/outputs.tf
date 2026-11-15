output "cluster_name" {
  description = "Name of the CloudNativePG cluster."
  value       = var.cluster_name
}

output "rw_service_name" {
  description = "Kubernetes Service name for read-write PostgreSQL connections."
  value       = "${var.cluster_name}-cluster-rw"
}

output "databases" {
  description = "Names of the application databases provisioned in the PostgreSQL cluster."
  value       = ["temporal", "temporal_visibility", "litellm"]
}

output "user_secret_names" {
  description = "Map of PostgreSQL role name to its Kubernetes basic-auth Secret name."
  value       = { for k, s in kubernetes_secret_v1.db_user : k => s.metadata[0].name }
}
