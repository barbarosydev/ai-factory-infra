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

variable "model_routes" {
  description = "Map of agent route name to Ollama model tag."
  type        = map(string)
  default = {
    "pm-agent"  = "gemma4:12b"
    "dev-agent" = "gemma4:e4b"
    "sec-agent" = "gemma4:e4b"
  }
}
