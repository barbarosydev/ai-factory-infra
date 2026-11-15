output "service_name" {
  description = "Kubernetes Service name for LiteLLM."
  value       = var.release_name
}

output "ingress_url" {
  description = "Local HTTP URL for LiteLLM via Traefik."
  value       = "http://${var.ingress_host}:8080"
}

output "masterkey_secret_name" {
  description = "Kubernetes Secret name holding the LiteLLM master key."
  value       = kubernetes_secret_v1.master_key.metadata[0].name
}

output "agent_key_secret_names" {
  description = "Map of agent route name to the Kubernetes Secret holding its virtual key."
  value       = { for k, s in kubernetes_secret_v1.agent_key : k => s.metadata[0].name }
}
