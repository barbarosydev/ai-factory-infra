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

variable "kubeconfig_path" {
  description = "Absolute path of the project kubeconfig (a checkout's .kube/config). Empty uses this checkout's own. Set by scripts/terraform.sh so git worktrees share one cluster."
  type        = string
  default     = ""
  nullable    = false

  validation {
    condition     = var.kubeconfig_path == "" || (startswith(var.kubeconfig_path, "/") && endswith(var.kubeconfig_path, "/.kube/config") && var.kubeconfig_path != pathexpand("~/.kube/config"))
    error_message = "kubeconfig_path must be empty or the absolute path of a checkout's .kube/config, never the global ~/.kube/config."
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

variable "cnpg_operator_image_tag" {
  description = "CloudNativePG operator image tag and multi-arch index digest (ghcr.io/cloudnative-pg/cloudnative-pg); the version is the operator chart's appVersion."
  type        = string
  default     = "1.30.1@sha256:923c267ec29636db3bee20f993d0ec4973fa22998e1adad37da79e4d32b5bc07"
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+@sha256:[0-9a-f]{64}$", var.cnpg_operator_image_tag))
    error_message = "cnpg_operator_image_tag must be an exact version plus index digest: X.Y.Z@sha256:<64 hex>."
  }
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
  default     = "18"
  nullable    = false

  validation {
    condition     = contains(["15", "16", "17", "18"], var.postgres_version)
    error_message = "PostgreSQL major version must be 15, 16, 17, or 18."
  }
}

variable "postgres_image_name" {
  description = "PostgreSQL container image as repository:MAJOR.MINOR@sha256:digest (multi-arch index digest). The major must equal postgres_version."
  type        = string
  default     = "ghcr.io/cloudnative-pg/postgresql:18.6@sha256:899d3ed526b659d77935dde0e6bf2d69dbbf17d3d8c6486ca8cfd04bd3c18533"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9./-]+:${var.postgres_version}\\.[0-9]+@sha256:[0-9a-f]{64}$", var.postgres_image_name))
    error_message = "postgres_image_name must be repository:MAJOR.MINOR@sha256:<64 hex> with MAJOR equal to postgres_version."
  }
}

variable "litellm_chart_version" {
  description = "Pinned LiteLLM Helm chart and container image version."
  type        = string
  default     = "1.109.1"
  nullable    = false
}

variable "litellm_image_tag" {
  description = "LiteLLM image tag and multi-arch index digest (ghcr.io/berriai/litellm); the version must equal litellm_chart_version."
  type        = string
  default     = "1.109.1@sha256:11175975a3093e05e92faee2fe2fe3412a3ae2fcaa849eb0fe25d5f0d8bcb2e9"
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+@sha256:[0-9a-f]{64}$", var.litellm_image_tag)) && startswith(var.litellm_image_tag, "${var.litellm_chart_version}@")
    error_message = "litellm_image_tag must be an exact version plus index digest: X.Y.Z@sha256:<64 hex> with X.Y.Z equal to litellm_chart_version."
  }
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
  description = "temporalio/server image tag and multi-arch index digest."
  type        = string
  default     = "1.32.2@sha256:7bf69188a6232fea14869b9cef3d94aa82a1601d99517f7e86c71f22da4e0670"
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+@sha256:[0-9a-f]{64}$", var.temporal_server_image_tag))
    error_message = "temporal_server_image_tag must be an exact version plus index digest: X.Y.Z@sha256:<64 hex>."
  }
}

variable "temporal_admin_tools_image_tag" {
  description = "temporalio/admin-tools image tag and multi-arch index digest; the version must equal the temporal_server_image_tag version."
  type        = string
  default     = "1.32.2@sha256:4a95866efba29d7e17ab012df5232795e8b0ad0f7d5f9d1ec4df321f7792a754"
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+@sha256:[0-9a-f]{64}$", var.temporal_admin_tools_image_tag)) && split("@", var.temporal_admin_tools_image_tag)[0] == split("@", var.temporal_server_image_tag)[0]
    error_message = "temporal_admin_tools_image_tag must be an exact version plus index digest: X.Y.Z@sha256:<64 hex> with the same X.Y.Z as temporal_server_image_tag."
  }
}

variable "temporal_ui_image_tag" {
  description = "temporalio/ui image tag and multi-arch index digest."
  type        = string
  default     = "2.56.1@sha256:584dd3408ab8333888d50b12d4a683e550e963409bf95fa2c9159d40d7cb825f"
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+@sha256:[0-9a-f]{64}$", var.temporal_ui_image_tag))
    error_message = "temporal_ui_image_tag must be an exact version plus index digest: X.Y.Z@sha256:<64 hex>."
  }
}

variable "model_routes" {
  description = "Map of agent route name to Ollama model tag."
  type        = map(string)
  default = {
    "pm-agent"   = "gemma4:12b"
    "dev-agent"  = "gemma4:e4b"
    "test-agent" = "gemma4:e4b"
    "sec-agent"  = "gemma4:e4b"
  }
  nullable = false

  validation {
    condition     = length(var.model_routes) > 0 && alltrue([for k, v in var.model_routes : length(trimspace(k)) > 0 && length(trimspace(v)) > 0])
    error_message = "model_routes must contain at least one non-empty agent route and Ollama model tag."
  }
}
