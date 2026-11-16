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

output "ollama_service" {
  description = "Kubernetes Service name routing to Ollama on the Mac."
  value       = module.model_backend.service_name
}

output "litellm_url" {
  description = "Local HTTP URL for LiteLLM via Traefik."
  value       = module.litellm.ingress_url
}

output "litellm_masterkey_secret" {
  description = "Kubernetes Secret name holding the LiteLLM master key."
  value       = module.litellm.masterkey_secret_name
}

output "litellm_agent_key_secrets" {
  description = "Map of agent route name to the Kubernetes Secret holding its virtual key."
  value       = module.litellm.agent_key_secret_names
}

output "temporal_web_url" {
  description = "Local HTTP URL for the Temporal Web UI via Traefik."
  value       = module.temporal.web_url
}

output "temporal_grpc_endpoint" {
  description = "Host gRPC endpoint for the Temporal CLI and SDK workers on the Mac."
  value       = module.temporal.grpc_endpoint
}

output "temporal_frontend_service" {
  description = "Kubernetes Service name for the Temporal gRPC frontend."
  value       = module.temporal.frontend_service_name
}
