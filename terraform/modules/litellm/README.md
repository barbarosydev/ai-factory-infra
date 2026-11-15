# terraform/modules/litellm

Installs the official LiteLLM Helm chart (`oci://ghcr.io/berriai/litellm-helm`, version `1.109.1`) backed by PostgreSQL, configures the Ollama model routes (`pm-agent`, `dev-agent`, `sec-agent`), exposes `http://litellm.localhost:8080` through Traefik, and provisions the master key and one virtual key per agent without storing any key in Terraform state.
