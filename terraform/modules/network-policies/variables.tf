variable "namespace" {
  description = "Kubernetes namespace where NetworkPolicies are enforced."
  type        = string

  validation {
    condition     = length(trimspace(var.namespace)) > 0
    error_message = "namespace must not be empty."
  }
}

variable "cluster_pod_cidr" {
  description = "Pod CIDR excluded from host Ollama egress."
  type        = string
  default     = "10.42.0.0/16"
}

variable "service_cidr" {
  description = "Service CIDR excluded from host Ollama egress."
  type        = string
  default     = "10.43.0.0/16"
}
