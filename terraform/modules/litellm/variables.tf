variable "namespace" {
  description = "Kubernetes namespace where LiteLLM is deployed."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.namespace)) > 0
    error_message = "namespace must not be empty."
  }
}

variable "release_name" {
  description = "Helm release name for LiteLLM."
  type        = string
  default     = "litellm"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.release_name))
    error_message = "release_name must be a valid RFC 1123 DNS label."
  }
}

variable "chart_version" {
  description = "Pinned LiteLLM Helm chart and container image version."
  type        = string
  default     = "1.109.1"
  nullable    = false
}

variable "image_tag" {
  description = "LiteLLM image tag and multi-arch index digest (X.Y.Z@sha256:...) for ghcr.io/berriai/litellm."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+@sha256:[0-9a-f]{64}$", var.image_tag))
    error_message = "image_tag must be an exact version plus index digest: X.Y.Z@sha256:<64 hex>."
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

variable "db_name" {
  description = "PostgreSQL database name for LiteLLM."
  type        = string
  default     = "litellm"
  nullable    = false

  validation {
    condition     = length(trimspace(var.db_name)) > 0
    error_message = "db_name must not be empty."
  }
}

variable "db_secret_name" {
  description = "Kubernetes Secret name containing PostgreSQL username and password."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.db_secret_name)) > 0
    error_message = "db_secret_name must not be empty."
  }
}

variable "ollama_api_base" {
  description = "In-cluster HTTP base URL for the Ollama Service."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^https?://", var.ollama_api_base))
    error_message = "ollama_api_base must start with http:// or https://."
  }
}

variable "model_routes" {
  description = "Map of agent route name to Ollama model tag."
  type        = map(string)
  nullable    = false

  validation {
    condition     = length(var.model_routes) > 0 && alltrue([for k, v in var.model_routes : length(trimspace(k)) > 0 && length(trimspace(v)) > 0])
    error_message = "model_routes must contain at least one non-empty agent route and model tag."
  }
}

variable "ingress_host" {
  description = "Hostname for the Traefik Ingress exposing LiteLLM."
  type        = string
  default     = "litellm.localhost"
  nullable    = false

  validation {
    condition     = length(trimspace(var.ingress_host)) > 0
    error_message = "ingress_host must not be empty."
  }
}

variable "agent_max_budget" {
  description = "Per-agent virtual key budget in USD."
  type        = number
  default     = 100
  nullable    = false

  validation {
    condition     = var.agent_max_budget > 0
    error_message = "agent_max_budget must be greater than 0."
  }
}

variable "store_prompts_in_spend_logs" {
  description = "Whether LiteLLM stores request/response prompt payloads in spend logs for the Admin UI."
  type        = bool
  default     = false
  nullable    = false
}

variable "spend_logs_retention" {
  description = "Retention window for LiteLLM spend and daily tag usage logs (e.g. 3d, 7d, 24h)."
  type        = string
  default     = "3d"
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+(m|h|d)$", var.spend_logs_retention))
    error_message = "spend_logs_retention must be a positive duration like 3d, 7d, or 24h."
  }
}

variable "input_cost_per_token" {
  description = "Local reference input cost per token in USD so /ui/usage/ spend and key budget charts populate meaningfully on local Ollama models."
  type        = number
  default     = 0.0000002
  nullable    = false

  validation {
    condition     = var.input_cost_per_token >= 0
    error_message = "input_cost_per_token must be non-negative."
  }
}

variable "output_cost_per_token" {
  description = "Local reference output cost per token in USD so /ui/usage/ spend and key budget charts populate meaningfully on local Ollama models."
  type        = number
  default     = 0.0000006
  nullable    = false

  validation {
    condition     = var.output_cost_per_token >= 0
    error_message = "output_cost_per_token must be non-negative."
  }
}

variable "secret_version" {
  description = "Increment to rotate the LiteLLM master key and agent virtual keys."
  type        = number
  default     = 4
  nullable    = false

  validation {
    condition     = var.secret_version >= 1 && floor(var.secret_version) == var.secret_version
    error_message = "secret_version must be a positive integer."
  }
}
