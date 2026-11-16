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

# --- Centralized component versions & image overrides ----------------------

variable "cnpg_operator_chart_version" {
  description = "Pinned CloudNativePG operator Helm chart version."
  type        = string
  default     = "0.29.1"
  nullable    = false
}

variable "cnpg_cluster_chart_version" {
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
    error_message = "PostgreSQL major version must be 15, 16, or 17."
  }
}

variable "postgres_image_name" {
  description = "Optional explicit PostgreSQL container image (tag or tag@sha256:digest). Empty uses the CloudNativePG default for postgres_version."
  type        = string
  default     = ""
  nullable    = false
}

variable "litellm_chart_version" {
  description = "Pinned LiteLLM Helm chart and container image version."
  type        = string
  default     = "1.109.1"
  nullable    = false
}

variable "litellm_store_prompts" {
  description = "Whether LiteLLM stores request/response prompt payloads in spend logs for the Admin UI."
  type        = bool
  default     = true
  nullable    = false
}

variable "temporal_chart_version" {
  description = "Pinned Temporal Helm chart version."
  type        = string
  default     = "1.8.0"
  nullable    = false
}

variable "temporal_server_image_tag" {
  description = "Pinned container image tag for temporalio/server and temporalio/admin-tools."
  type        = string
  default     = "1.32.2"
  nullable    = false
}

variable "temporal_ui_image_tag" {
  description = "Pinned container image tag for temporalio/ui."
  type        = string
  default     = "2.56.1"
  nullable    = false
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
