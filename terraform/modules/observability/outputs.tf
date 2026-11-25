output "service_name" {
  description = "Kubernetes Service name for Arize Phoenix."
  value       = kubernetes_service_v1.phoenix.metadata[0].name
}

output "ingress_url" {
  description = "Local HTTP URL for the Arize Phoenix UI via Traefik."
  value       = "http://${var.ingress_host}:8080"
}

output "otlp_http_base_url" {
  description = "Host OTLP HTTP base URL via Traefik (OpenTelemetry SDKs append /v1/traces)."
  value       = "http://${var.ingress_host}:8080"
}

output "otlp_http_traces_endpoint" {
  description = "Full host OTLP HTTP/protobuf traces ingestion endpoint."
  value       = "http://${var.ingress_host}:8080/v1/traces"
}
