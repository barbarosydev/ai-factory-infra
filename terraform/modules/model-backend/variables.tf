variable "namespace" {
  description = "Kubernetes namespace for the model backend Service."
  type        = string
}

variable "service_name" {
  description = "Name of the Kubernetes Service exposing the model backend."
  type        = string
  default     = "ollama"
}

variable "host_address" {
  description = "DNS name of the host running Ollama."
  type        = string
  default     = "host.k3d.internal"
}

variable "port" {
  description = "TCP port where Ollama listens on the host."
  type        = number
  default     = 11434
}
