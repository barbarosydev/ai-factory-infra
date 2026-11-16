variable "namespace" {
  description = "Kubernetes namespace where Temporal is deployed."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.namespace)) > 0
    error_message = "namespace must not be empty."
  }
}

variable "release_name" {
  description = "Helm release name for Temporal."
  type        = string
  default     = "temporal"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.release_name))
    error_message = "release_name must be a valid RFC 1123 DNS label."
  }
}

variable "chart_version" {
  description = "Pinned Temporal Helm chart version."
  type        = string
  default     = "1.8.0"
  nullable    = false

  validation {
    condition     = length(trimspace(var.chart_version)) > 0
    error_message = "chart_version must not be empty."
  }
}

variable "server_image_tag" {
  description = "Pinned container image tag for temporalio/server and temporalio/admin-tools."
  type        = string
  default     = "1.32.2"
  nullable    = false

  validation {
    condition     = length(trimspace(var.server_image_tag)) > 0
    error_message = "server_image_tag must not be empty."
  }
}

variable "ui_image_tag" {
  description = "Pinned container image tag for temporalio/ui."
  type        = string
  default     = "2.56.1"
  nullable    = false

  validation {
    condition     = length(trimspace(var.ui_image_tag)) > 0
    error_message = "ui_image_tag must not be empty."
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
    condition     = var.db_port >= 1 && var.db_port <= 65535
    error_message = "db_port must be a valid TCP port (1-65535)."
  }
}

variable "default_db_name" {
  description = "PostgreSQL database name for Temporal default persistence store."
  type        = string
  default     = "temporal"
  nullable    = false

  validation {
    condition     = length(trimspace(var.default_db_name)) > 0
    error_message = "default_db_name must not be empty."
  }
}

variable "visibility_db_name" {
  description = "PostgreSQL database name for Temporal SQL visibility store."
  type        = string
  default     = "temporal_visibility"
  nullable    = false

  validation {
    condition     = length(trimspace(var.visibility_db_name)) > 0
    error_message = "visibility_db_name must not be empty."
  }
}

variable "db_user" {
  description = "PostgreSQL role owning the Temporal databases."
  type        = string
  default     = "temporal"
  nullable    = false

  validation {
    condition     = length(trimspace(var.db_user)) > 0
    error_message = "db_user must not be empty."
  }
}

variable "db_secret_name" {
  description = "Kubernetes Secret name containing PostgreSQL credentials for the Temporal user."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.db_secret_name)) > 0
    error_message = "db_secret_name must not be empty."
  }
}

variable "default_namespace_retention" {
  description = "Workflow execution retention period for the default Temporal namespace."
  type        = string
  default     = "3d"
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+(h|d)$", var.default_namespace_retention))
    error_message = "default_namespace_retention must be a duration such as 24h or 3d."
  }
}

variable "ingress_host" {
  description = "Hostname for the Traefik Ingress exposing the Temporal Web UI."
  type        = string
  default     = "temporal.localhost"
  nullable    = false

  validation {
    condition     = length(trimspace(var.ingress_host)) > 0
    error_message = "ingress_host must not be empty."
  }
}

variable "grpc_port" {
  description = "Frontend gRPC TCP port exposed via LoadBalancer to the Mac host."
  type        = number
  default     = 7233
  nullable    = false

  validation {
    condition     = var.grpc_port >= 1 && var.grpc_port <= 65535
    error_message = "grpc_port must be a valid TCP port (1-65535)."
  }
}
