variable "namespace" {
  description = "Kubernetes namespace where CloudNativePG and the PostgreSQL cluster are deployed."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.namespace)) > 0
    error_message = "namespace must not be empty."
  }
}

variable "cluster_name" {
  description = "Name of the CloudNativePG cluster and Helm release."
  type        = string
  default     = "ai-postgres"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.cluster_name))
    error_message = "cluster_name must be a valid RFC 1123 DNS label."
  }
}

variable "operator_chart_version" {
  description = "Pinned CloudNativePG operator Helm chart version."
  type        = string
  default     = "0.29.1"
  nullable    = false
}

variable "cluster_chart_version" {
  description = "Pinned CloudNativePG cluster Helm chart version."
  type        = string
  default     = "0.9.0"
  nullable    = false
}

variable "postgres_version" {
  description = "PostgreSQL major version supported by Temporal 1.32 and CloudNativePG."
  type        = string
  default     = "16"
  nullable    = false

  validation {
    condition     = contains(["15", "16", "17"], var.postgres_version)
    error_message = "postgres_version must be 15, 16, or 17."
  }
}

variable "postgres_image_name" {
  description = "Optional explicit PostgreSQL container image (tag or tag@sha256:digest). Empty uses the CloudNativePG default for postgres_version."
  type        = string
  default     = ""
  nullable    = false
}

variable "storage_size" {
  description = "Persistent volume size for the PostgreSQL data directory."
  type        = string
  default     = "8Gi"
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+(Mi|Gi|Ti)$", var.storage_size))
    error_message = "storage_size must be a Kubernetes quantity such as 4Gi or 8Gi."
  }
}

variable "password_version" {
  description = "Increment to rotate the generated database user passwords."
  type        = number
  default     = 1
  nullable    = false

  validation {
    condition     = var.password_version >= 1 && floor(var.password_version) == var.password_version
    error_message = "password_version must be a positive integer."
  }
}
