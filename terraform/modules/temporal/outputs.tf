output "frontend_service_name" {
  description = "Kubernetes Service name for the Temporal gRPC frontend."
  value       = "${var.release_name}-frontend"
}

output "grpc_endpoint" {
  description = "Host gRPC endpoint for the Temporal CLI and SDK workers on the Mac."
  value       = "localhost:${var.grpc_port}"
}

output "web_url" {
  description = "Local HTTP URL for the Temporal Web UI via Traefik."
  value       = "http://${var.ingress_host}:8080"
}
