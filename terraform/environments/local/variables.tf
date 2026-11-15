variable "kube_context" {
  description = "Kubeconfig context name for the local k3d cluster."
  type        = string
  default     = "k3d-ai-factory"
  nullable    = false

  validation {
    condition     = var.kube_context == "k3d-ai-factory"
    error_message = "Only the k3d-ai-factory context is allowed for the local environment."
  }
}

variable "namespace" {
  description = "Kubernetes namespace for the AI platform stack."
  type        = string
  default     = "ai-platform"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace))
    error_message = "Namespace must be a valid RFC 1123 DNS label."
  }
}

variable "postgres_version" {
  description = "PostgreSQL major version supported by Temporal 1.32 and CloudNativePG."
  type        = string
  default     = "16"
  nullable    = false

  validation {
    condition     = contains(["15", "16", "17"], var.postgres_version)
    error_message = "PostgreSQL major version must be 15, 16, or 17."
  }
}

variable "model_routes" {
  description = "Map of agent route name to Ollama model tag."
  type        = map(string)
  default = {
    "pm-agent"  = "gemma4:12b"
    "dev-agent" = "gemma4:e4b"
    "sec-agent" = "gemma4:e4b"
  }
  nullable = false

  validation {
    condition     = length(var.model_routes) > 0 && alltrue([for k, v in var.model_routes : length(trimspace(k)) > 0 && length(trimspace(v)) > 0])
    error_message = "model_routes must contain at least one non-empty agent route and Ollama model tag."
  }
}
