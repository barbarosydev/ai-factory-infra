variable "namespace" {
  description = "Kubernetes namespace where LiteLLM is deployed."
  type        = string
}

variable "release_name" {
  description = "Helm release name for LiteLLM."
  type        = string
  default     = "litellm"
}

variable "db_endpoint" {
  description = "PostgreSQL read-write Service hostname."
  type        = string
}

variable "db_name" {
  description = "PostgreSQL database name for LiteLLM."
  type        = string
  default     = "litellm"
}

variable "db_secret_name" {
  description = "Kubernetes Secret name containing PostgreSQL username and password."
  type        = string
}

variable "ollama_api_base" {
  description = "In-cluster HTTP base URL for the Ollama Service."
  type        = string
}

variable "model_routes" {
  description = "Map of agent route name to Ollama model tag."
  type        = map(string)
}

variable "ingress_host" {
  description = "Hostname for the Traefik Ingress exposing LiteLLM."
  type        = string
  default     = "litellm.localhost"
}

variable "agent_max_budget" {
  description = "Per-agent virtual key budget in USD."
  type        = number
  default     = 100
}

variable "secret_version" {
  description = "Increment to rotate the LiteLLM master key and agent virtual keys."
  type        = number
  default     = 1
}
