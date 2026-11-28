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

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.operator_chart_version))
    error_message = "operator_chart_version must be an exact semantic version (X.Y.Z)."
  }
}

variable "operator_image_tag" {
  description = "CloudNativePG operator image tag and multi-arch index digest (X.Y.Z@sha256:...); also used for the instance manager in PostgreSQL pods."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+@sha256:[0-9a-f]{64}$", var.operator_image_tag))
    error_message = "operator_image_tag must be an exact version plus index digest: X.Y.Z@sha256:<64 hex>."
  }
}

variable "cluster_chart_version" {
  description = "Pinned CloudNativePG cluster Helm chart version."
  type        = string
  default     = "0.9.0"
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.cluster_chart_version))
    error_message = "cluster_chart_version must be an exact semantic version (X.Y.Z)."
  }
}

variable "postgres_version" {
  description = "PostgreSQL major version supported by Temporal 1.32 and CloudNativePG."
  type        = string
  default     = "18"
  nullable    = false

  validation {
    condition     = contains(["15", "16", "17", "18"], var.postgres_version)
    error_message = "postgres_version must be 15, 16, 17, or 18."
  }
}

variable "postgres_image_name" {
  description = "PostgreSQL container image as repository:MAJOR.MINOR@sha256:digest (multi-arch index digest). The major must equal postgres_version."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9./-]+:${var.postgres_version}\\.[0-9]+@sha256:[0-9a-f]{64}$", var.postgres_image_name))
    error_message = "postgres_image_name must be repository:MAJOR.MINOR@sha256:<64 hex> with MAJOR equal to postgres_version."
  }
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
