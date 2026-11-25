variable "namespace" {
  description = "Kubernetes namespace where Arize Phoenix is deployed."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.namespace)) > 0
    error_message = "namespace must not be empty."
  }
}

variable "service_name" {
  description = "Kubernetes Deployment and Service name for Arize Phoenix."
  type        = string
  default     = "phoenix"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.service_name))
    error_message = "service_name must be a valid RFC 1123 DNS label."
  }
}

variable "image_name" {
  description = "Arize Phoenix container image pinned by exact tag and multi-arch index digest (repository:tag@sha256:...)."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9./-]+:[a-zA-Z0-9._-]+@sha256:[0-9a-f]{64}$", var.image_name)) && !can(regex("(^|:)latest(@|$)", var.image_name))
    error_message = "image_name must be repository:tag@sha256:<64 hex> and must not use latest."
  }
}

variable "db_endpoint" {
  description = "PostgreSQL read-write Service hostname."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.db_endpoint)) > 0
    error_message = "db_endpoint must not be empty."
  }
}

variable "db_port" {
  description = "PostgreSQL TCP port."
  type        = number
  default     = 5432
  nullable    = false

  validation {
    condition     = var.db_port >= 1 && var.db_port <= 65535 && floor(var.db_port) == var.db_port
    error_message = "db_port must be an integer TCP port between 1 and 65535."
  }
}

variable "db_name" {
  description = "PostgreSQL database name dedicated to Phoenix."
  type        = string
  default     = "phoenix"
  nullable    = false

  validation {
    condition     = length(trimspace(var.db_name)) > 0
    error_message = "db_name must not be empty."
  }
}

variable "db_secret_name" {
  description = "Kubernetes Secret name containing PostgreSQL username and password keys."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.db_secret_name)) > 0
    error_message = "db_secret_name must not be empty."
  }
}

variable "ingress_host" {
  description = "Hostname for the Traefik Ingress exposing Arize Phoenix."
  type        = string
  default     = "phoenix.localhost"
  nullable    = false

  validation {
    condition     = length(trimspace(var.ingress_host)) > 0
    error_message = "ingress_host must not be empty."
  }
}

variable "http_port" {
  description = "HTTP UI and OTLP HTTP/protobuf receiver port exposed by Phoenix."
  type        = number
  default     = 6006
  nullable    = false

  validation {
    condition     = var.http_port >= 1 && var.http_port <= 65535 && floor(var.http_port) == var.http_port
    error_message = "http_port must be an integer TCP port between 1 and 65535."
  }
}

variable "retention_days" {
  description = "Default trace retention policy in days applied by Phoenix."
  type        = number
  default     = 3
  nullable    = false

  validation {
    condition     = var.retention_days >= 1 && floor(var.retention_days) == var.retention_days
    error_message = "retention_days must be a positive integer."
  }
}
