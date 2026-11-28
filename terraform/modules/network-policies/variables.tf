variable "namespace" {
  description = "Kubernetes namespace where NetworkPolicies are enforced."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.namespace)) > 0
    error_message = "namespace must not be empty."
  }
}

variable "cluster_pod_cidr" {
  description = "Pod CIDR excluded from host Ollama egress."
  type        = string
  default     = "10.42.0.0/16"
  nullable    = false

  validation {
    condition     = can(cidrhost(var.cluster_pod_cidr, 0))
    error_message = "cluster_pod_cidr must be a valid IPv4/IPv6 CIDR block."
  }
}

variable "service_cidr" {
  description = "Service CIDR excluded from host Ollama egress."
  type        = string
  default     = "10.43.0.0/16"
  nullable    = false

  validation {
    condition     = can(cidrhost(var.service_cidr, 0))
    error_message = "service_cidr must be a valid IPv4/IPv6 CIDR block."
  }
}
