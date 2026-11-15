variable "namespace" {
  description = "Kubernetes namespace where CloudNativePG and the PostgreSQL cluster are deployed."
  type        = string
}

variable "cluster_name" {
  description = "Name of the CloudNativePG cluster and Helm release."
  type        = string
  default     = "ai-postgres"
}

variable "postgres_version" {
  description = "PostgreSQL major version supported by Temporal 1.32 and CloudNativePG."
  type        = string
  default     = "16"
}

variable "storage_size" {
  description = "Persistent volume size for the PostgreSQL data directory."
  type        = string
  default     = "8Gi"
}

variable "password_version" {
  description = "Increment to rotate the generated database user passwords."
  type        = number
  default     = 1
}
