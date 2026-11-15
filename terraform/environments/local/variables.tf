variable "kube_context" {
  description = "Kubeconfig context name for the local k3d cluster."
  type        = string
  default     = "k3d-ai-factory"
}

variable "namespace" {
  description = "Kubernetes namespace for the AI platform stack."
  type        = string
  default     = "ai-platform"
}

variable "postgres_version" {
  description = "PostgreSQL major version."
  type        = string
  default     = "16"
}
