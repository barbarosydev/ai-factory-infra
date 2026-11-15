output "service_name" {
  description = "Name of the Kubernetes Service routing to the model backend."
  value       = kubernetes_service_v1.ollama.metadata[0].name
}

output "api_base" {
  description = "In-cluster HTTP base URL for the model backend."
  value       = "http://${kubernetes_service_v1.ollama.metadata[0].name}:${var.port}"
}
