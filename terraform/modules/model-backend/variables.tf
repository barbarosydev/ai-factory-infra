variable "namespace" {
  description = "Kubernetes namespace for the model backend Service."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.namespace)) > 0
    error_message = "namespace must not be empty."
  }
}

variable "service_name" {
  description = "Name of the Kubernetes Service exposing the model backend."
  type        = string
  default     = "ollama"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.service_name))
    error_message = "service_name must be a valid RFC 1123 DNS label."
  }
}

variable "host_address" {
  description = "DNS name of the host running Ollama."
  type        = string
  default     = "host.k3d.internal"
  nullable    = false

  validation {
    condition     = length(trimspace(var.host_address)) > 0
    error_message = "host_address must not be empty."
  }
}

variable "port" {
  description = "TCP port where Ollama listens on the host."
  type        = number
  default     = 11434
  nullable    = false

  validation {
    condition     = var.port >= 1 && var.port <= 65535
    error_message = "port must be between 1 and 65535."
  }
}
